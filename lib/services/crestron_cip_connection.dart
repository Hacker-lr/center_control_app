import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// Crestron CIP / SCIP 协议连接客户端（单例）
///
/// 通过 Crestron-over-IP (CIP) 协议与 Crestron 控制处理器通信。
/// - 3 系列 / 未加密 CIP：明文 TCP，默认端口 41794。
/// - 4 系列 / 安全 CIP (SCIP)：TLS 加密 TCP，默认端口 41796，需认证。
///
/// 协议帧格式（基于 python-cipclient 逆向，逐字节核对）：
///   [type:1][length:2 大端][payload:length]
///
/// 握手顺序：
///   明文 CIP（3 系列 / 关闭验证）：
///     连接 → 处理器发 0x0F(注册请求)
///          → 客户端回 0x01(注册包，含 IP-ID)
///          → 处理器回 0x02(成功 = 00 00 00 1F)
///          → 客户端发 0x05(update request) → 处理器回 0x1C → 0x1D + 心跳
///
///   SCIP（4 系列 / 41796 加密，开启身份验证）：
///     TLS 连接 → 客户端先发 0x0B 登录包(username:password)
///             → 处理器回 0x0C(成功 = 00 00 01)
///             → 处理器发 0x0F(注册请求)
///             → 客户端回 0x01(注册包，含 IP-ID)
///             → 处理器回 0x02(成功 = 00 00 00 1F)
///     登录包格式（参考 scip2cip 逆向，逐字节核对）：
///       0x0B 00 `<len>` 00 00 `<username:password ASCII>` 00 00 00
/// ============================================================

/// Join 变化回调类型
typedef CipJoinCallback =
    void Function(String sigtype, int join, dynamic value);

class CrestronCipConnection extends BaseConnection {
  static final CrestronCipConnection _instance =
      CrestronCipConnection._internal();
  factory CrestronCipConnection() => _instance;
  CrestronCipConnection._internal();

  final DeviceConfig _config = DeviceConfig();

  /// 应用层（CIP）是否已握手完成
  bool _cipConnected = false;
  bool get isCipConnected => _cipConnected;

  /// 接收缓冲区（用于跨 TCP 分片重组 CIP 帧）
  final List<int> _rxBuffer = [];

  /// join 状态机：存储每个 join 当前值，供 get() 读取
  /// _state[direction][sigtype][join] = value
  final Map<String, Map<String, Map<int, dynamic>>> _state = {
    'in': {'d': {}, 'a': {}, 's': {}},
    'out': {'d': {}, 'a': {}, 's': {}},
  };

  /// 订阅回调表：key = "$sigtype:$join:$direction"
  final Map<String, Set<CipJoinCallback>> _subscribers = {};

  /// 最近事件日志（供 UI 反馈），最多保留 200 条
  final List<String> _eventLog = [];

  /// 安全认证调试日志（4 系列抓包用）
  final List<String> _authLog = [];

  /// SCIP 登录包(0x0B)是否已发送，避免重复发送
  bool _loginSent = false;

  // ===================== 基类抽象属性实现 =====================

  @override
  String get deviceIp => _config.cipHost;

  @override
  int get devicePort => _config.cipPort;

  @override
  bool get useTcp => true;

  /// CIP 心跳包固定为 0x0D 00 02 00 00（base 心跳定时器每 heartbeatInterval 秒发送）
  @override
  String get heartbeatCommand => '0D 00 02 00 00';

  @override
  bool get sendAsHex => true;

  /// CIP 心跳间隔 2 秒：配合看门狗（每 1s 比对时间戳）实现约 4~5 秒内的离线感知，
  /// 同时只是每 2 秒一个 5 字节小包，几乎不占用资源
  @override
  int get heartbeatInterval => 2;

  /// CIP 心跳超时倍数：连续 2 个周期(=10s)无响应即判定离线，
  /// 配合 5s 间隔实现快速反馈（取值偏保守，避免正常抖动误判）
  @override
  int get heartbeatTimeoutMultiplier => 2;

  /// 安全模式（SCIP）：通过 TLS 连接处理器
  @override
  Future<Socket> createTcpSocket() async {
    if (_config.cipSecure) {
      // 4 系列安全 CIP：TLS 封装。Crestron 常用自签名证书，
      // 此处 onBadCertificate 直接放行；生产环境应做证书校验。
      return await SecureSocket.connect(
        deviceIp,
        devicePort,
        timeout: Duration(seconds: _config.connectionTimeoutSeconds),
        onBadCertificate: (cert) => true,
      );
    }
    return await Socket.connect(
      deviceIp,
      devicePort,
      timeout: Duration(seconds: _config.connectionTimeoutSeconds),
    );
  }

  // ===================== 接收数据解析（基类钩子） =====================

  /// TCP 连接建立：复位协议状态机，等待处理器发 0x0F 注册请求
  @override
  void onTransportConnected() {
    _rxBuffer.clear();
    _loginSent = false;
    _setCipConnected(false);
    _logEvent('TCP 已连接 $deviceIp:$devicePort，等待处理器注册请求(0x0F)...');
    // SCIP（4 系列加密）模式：TLS 连上后立即发送 0x0B 登录包完成身份验证，
    // 否则 CP4 在收到 0x01 注册包时会以 0x40 reject（未认证）。
    // 参考 scip2cip 项目逆向：登录包格式 0x0B 00 `<len>` 00 00 `<user:pass>` 00 00 00
    if (_config.cipSecure) {
      _sendLoginPacket();
    }
  }

  /// 构造并发送 SCIP 0x0B 登录包（含 username:password）
  Future<void> _sendLoginPacket() async {
    if (_loginSent) return;
    _loginSent = true;
    final Uint8List pkt = _buildLoginPacket();
    _logEvent('→ SCIP 登录包 [${_hex(pkt)}]');
    await _send(pkt);
  }

  /// SCIP 登录包（参考 scip2cip 逆向实现的字节结构）
  /// 帧：0x0B 00 `<len>` 00 00 `<username:password>` 00 00 00
  Uint8List _buildLoginPacket() {
    final String cred = '${_config.cipUsername}:${_config.cipPassword}';
    final List<int> credBytes = cred.codeUnits;
    final List<int> payload = [0x00, 0x00, ...credBytes, 0x00, 0x00, 0x00];
    return _frame(0x0B, payload);
  }

  /// 传输层断开：复位握手状态与接收缓冲，避免重连后解析错乱
  @override
  void onTransportDisconnected() {
    _rxBuffer.clear();
    _loginSent = false;
    _setCipConnected(false);
  }

  @override
  void processReceivedData(Uint8List data) {
    _rxBuffer.addAll(data);
    _parseFrames();
  }

  void _parseFrames() {
    while (_rxBuffer.length >= 3) {
      final int type = _rxBuffer[0];
      final int length = (_rxBuffer[1] << 8) | _rxBuffer[2];
      if (_rxBuffer.length < 3 + length) break; // 帧未接收完整，等待更多数据
      final Uint8List payload = Uint8List.fromList(
        _rxBuffer.sublist(3, 3 + length),
      );
      _rxBuffer.removeRange(0, 3 + length);
      _handlePacket(type, payload);
    }
  }

  void _handlePacket(int type, Uint8List payload) {
    switch (type) {
      case 0x0C:
        // SCIP 登录响应（参考 scip2cip：成功 = 0C 00 03 00 00 01）。
        // 仅记录，不主动断开——真正的成功/失败由后续 0x02 注册结果裁定，
        // 避免把固件变体下的成功码误判为失败而断连。
        if (_eq(payload, [0x00, 0x00, 0x01])) {
          _logEvent('✓ SCIP 登录成功(0x0C)，等待注册请求(0x0F)…');
        } else {
          _logEvent(
            '收到 0x0C 登录响应(非标准成功码): ${_hex(payload)}'
            '（若后续注册仍被拒，请检查 CP4 用户名/密码是否正确）',
          );
        }
        break;
      case 0x0F:
        // 服务器注册请求 → 回应注册包（含 IP-ID）
        // SCIP 模式下若登录包尚未发出（理论上 onTransportConnected 已发），补发一次
        if (_config.cipSecure && !_loginSent) {
          _sendLoginPacket();
        }
        _logEvent(
          '收到注册请求(0x0F)，payload=${_hex(payload)}，发送 IP-ID 0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()} 注册包',
        );
        _send(_buildRegistration(_config.cipIpId));
        break;
      case 0x02:
        // 注册结果
        if (_eq(payload, [0x00, 0x00, 0x00, 0x1f])) {
          _logEvent('注册成功，发送 update request');
          _send(_buildUpdateRequest());
        } else if (_eq(payload, [0xff, 0xff, 0x02])) {
          _logEvent(
            '✗ IP-ID 0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()} 在处理器上不存在！'
            '请核对 SIMPL 程序中 XPanel 符号的 IP-ID（注意它是十六进制）',
          );
          notifyConnectionError();
        } else {
          _logEvent('✗ 注册失败: ${_hex(payload)}${_explainReject(payload)}');
          notifyConnectionError();
        }
        break;
      case 0x0D:
      case 0x0E:
        // 心跳 ping / pong，忽略（基类已更新 lastHeartbeatResponse）
        break;
      case 0x05:
        _handleData(payload);
        break;
      case 0x12:
        _handleSerial(payload);
        break;
      case 0x03:
        _logEvent('✗ 控制系统中断，准备重连');
        notifyConnectionError();
        break;
      default:
        // 未知类型。安全模式下可能是认证挑战包，记录下来供抓包分析
        debugPrint(
          '[Cip] 未处理包类型 0x${type.toRadixString(16)}: ${_hex(payload)}',
        );
        // ⚠️ 仅 4 系列 + cipSecure 时进入；调用的认证桩为未验证实现，
        // 切勿在生产环境依赖其正确性（详见 _handleAuthChallenge 顶部说明）
        if (_config.cipSecure) _handleAuthChallenge(type, payload);
    }
  }

  void _handleData(Uint8List payload) {
    if (payload.length < 4) return;
    final int datatype = payload[3];
    switch (datatype) {
      case 0x00: // 数字 join
        if (payload.length >= 6) {
          final int join = ((payload[5] & 0x7F) << 8 | payload[4]) + 1;
          final int state = ((payload[5] & 0x80) >> 7) ^ 0x01;
          _updateState('d', join, state, 'in');
        }
        break;
      case 0x14: // 模拟 join
        if (payload.length >= 8) {
          final int join = ((payload[4] << 8) | payload[5]) + 1;
          final int value = (payload[6] << 8) | payload[7];
          _updateState('a', join, value, 'in');
        }
        break;
      case 0x03: // update request 子类型
        final int sub = payload.length > 4 ? payload[4] : -1;
        if (sub == 0x1C) {
          // end-of-query：回 0x1D + 心跳，置 connected 并重发 out join
          _send(_buildEndOfQueryAck());
          _send(_buildPing());
          _logEvent('✓ CIP 握手完成，连接就绪');
          _setCipConnected(true);
          _resendOutJoins();
        }
        break;
      default:
        // 0x08 日期时间等其它数据类型，忽略
        break;
    }
  }

  void _handleSerial(Uint8List payload) {
    if (payload.length >= 8) {
      final int join = ((payload[5] << 8) | payload[6]) + 1;
      final String value = String.fromCharCodes(payload.sublist(8));
      _updateState('s', join, value, 'in');
    }
  }

  // ===================== 对外 API =====================

  /// 设置 join 状态（d/a/s）
  /// d: value 0/1（或 bool）；a: 0-65535；s: 字符串
  Future<void> set(String sigtype, int join, dynamic value) async {
    if (!_cipConnected) {
      _logEvent('⚠️ 忽略 set($sigtype,$join)：CIP 尚未握手完成');
      return;
    }
    Uint8List pkt;
    switch (sigtype) {
      case 'd':
        final int v = (value is bool) ? (value ? 1 : 0) : (value == 0 ? 0 : 1);
        pkt = _buildDigital(join, v);
        _recordOut('d', join, v);
        break;
      case 'a':
        int v = value is int ? value : (int.tryParse(value.toString()) ?? 0);
        v = v.clamp(0, 65535);
        pkt = _buildAnalog(join, v);
        _recordOut('a', join, v);
        break;
      case 's':
        final String s = value.toString();
        pkt = _buildSerial(join, s);
        _recordOut('s', join, s);
        break;
      default:
        debugPrint('[Cip] 未知信号类型: $sigtype');
        return;
    }
    _logEvent('→ $sigtype$join = $value  [${_hex(pkt)}]');
    await _send(pkt);
  }

  /// 数字 join 脉冲：高 → 保持 [hold] → 低。
  /// 必须保持一小段时间（默认由 DeviceConfig.cipPulseHoldMs 控制，约 80ms），
  /// 否则 Crestron 处理器按扫描周期采样，≈0 时长的脉冲会被直接跳过，
  /// 中控收不到点击指令。保持时长可在配置页调整。
  Future<void> pulse(int join, {Duration? hold}) async {
    if (!_cipConnected) {
      _logEvent('⚠️ 忽略 pulse(d$join)：CIP 尚未握手完成');
      return;
    }
    final Duration h = hold ?? Duration(milliseconds: _config.cipPulseHoldMs);
    await set('d', join, 1);
    await Future.delayed(h);
    await set('d', join, 0);
  }

  /// 模拟触摸面板"按下"（按钮型数字 join，保持高直到 release）
  Future<void> press(int join) async {
    if (!_cipConnected) {
      _logEvent('⚠️ 忽略 press(d$join)：CIP 尚未握手完成');
      return;
    }
    final Uint8List pkt = _buildDigital(join, 1, button: true);
    _logEvent('↓ press d$join  [${_hex(pkt)}]');
    _recordOut('d', join, 1);
    await _send(pkt);
  }

  /// 模拟触摸面板"释放"
  Future<void> release(int join) async {
    if (!_cipConnected) {
      _logEvent('⚠️ 忽略 release(d$join)：CIP 尚未握手完成');
      return;
    }
    final Uint8List pkt = _buildDigital(join, 0, button: true);
    _logEvent('↑ release d$join  [${_hex(pkt)}]');
    _recordOut('d', join, 0);
    await _send(pkt);
  }

  /// 读取 join 当前状态（direction: 'in' 入站 / 'out' 出站）
  dynamic get(String sigtype, int join, {String direction = 'in'}) {
    return _state[direction]?[sigtype]?[join];
  }

  /// 订阅 join 变化，返回取消订阅的 token（字符串）
  String subscribe(
    String sigtype,
    int join,
    CipJoinCallback cb, {
    String direction = 'in',
  }) {
    final String key = _subKey(sigtype, join, direction);
    _subscribers.putIfAbsent(key, () => <CipJoinCallback>{}).add(cb);
    // 立即回调当前已知值
    final cur = get(sigtype, join, direction: direction);
    if (cur != null) cb(sigtype, join, cur);
    return key;
  }

  /// 取消订阅
  void unsubscribe(String token) {
    _subscribers.remove(token);
  }

  /// 主动发起 update request（首次连接自动执行，此方法用于手动同步）
  Future<void> updateRequest() async {
    if (_cipConnected) await _send(_buildUpdateRequest());
  }

  // ===================== 状态机与通知 =====================

  void _setCipConnected(bool v) {
    if (_cipConnected == v) return;
    _cipConnected = v;
    notifyListeners();
  }

  void _updateState(String sigtype, int join, dynamic value, String direction) {
    _state[direction]?[sigtype]?[join] = value;
    _emit(sigtype, join, value, direction);
  }

  void _recordOut(String sigtype, int join, dynamic value) {
    _state['out']?[sigtype]?[join] = value;
  }

  void _emit(String sigtype, int join, dynamic value, String direction) {
    final String key = _subKey(sigtype, join, direction);
    _subscribers[key]?.forEach((cb) => cb(sigtype, join, value));
    _logEvent('${direction == 'in' ? '←' : '→'} $sigtype$join = $value');
  }

  /// 记录事件日志（握手过程 + join 变化），供 UI 反馈面板展示
  void _logEvent(String entry) {
    debugPrint('[Cip] $entry');
    _eventLog.add(entry);
    if (_eventLog.length > 200) _eventLog.removeAt(0);
    notifyListeners();
  }

  void _resendOutJoins() {
    final Map<String, Map<int, dynamic>> out = _state['out']!;
    out['d']?.forEach((join, value) async {
      await _send(_buildDigital(join, value as int));
    });
    out['a']?.forEach((join, value) async {
      await _send(_buildAnalog(join, value as int));
    });
    out['s']?.forEach((join, value) async {
      await _send(_buildSerial(join, value as String));
    });
  }

  // ===================== CIP 帧构造 =====================

  /// 发送 CIP 帧。
  /// 串行化已统一由基类 TCP 写队列保证（rawSend 内部入队），
  /// 心跳、指令、CIP 帧共用同一队列，任何时刻只有一个 add+flush 在执行。
  Future<void> _send(Uint8List data) async {
    await rawSend(data);
  }

  Uint8List _frame(int type, List<int> payload) {
    return Uint8List.fromList([
      type,
      (payload.length >> 8) & 0xFF,
      payload.length & 0xFF,
      ...payload,
    ]);
  }

  Uint8List _buildRegistration(int ipid) {
    // 0x01 注册包：payload = 00 00 00 00 00 <ipid> 40 ff ff f1 01
    final payload = [
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      ipid & 0xFF,
      0x40,
      0xff,
      0xff,
      0xf1,
      0x01,
    ];
    return _frame(0x01, payload);
  }

  Uint8List _buildUpdateRequest() =>
      _frame(0x05, [0x00, 0x00, 0x02, 0x03, 0x00]);

  Uint8List _buildEndOfQueryAck() =>
      _frame(0x05, [0x00, 0x00, 0x02, 0x03, 0x1d]);

  Uint8List _buildPing() => _frame(0x0D, [0x00, 0x00]);

  Uint8List _buildDigital(int join, int value, {bool button = false}) {
    final int cip = join - 1;
    int b0 = cip & 0xFF;
    int b1 = (cip >> 8) & 0xFF;
    if (value == 0) b1 |= 0x80; // 低电平置高字节最高位（与 python-cipclient 一致）
    final header = button
        ? [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x27]
        : [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x00];
    return Uint8List.fromList(header + [b0, b1]);
  }

  Uint8List _buildAnalog(int join, int value) {
    final int cip = join - 1;
    final payload = [
      0x00,
      0x00,
      0x05,
      0x14,
      (cip >> 8) & 0xFF,
      cip & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
    return _frame(0x05, payload);
  }

  Uint8List _buildSerial(int join, String value) {
    final int cip = join - 1;
    final List<int> bytes = value.codeUnits;
    final int l = bytes.length;
    // 与 python-cipclient 逐字节一致
    final pkt = <int>[0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x34];
    pkt[2] = 8 + l;
    pkt[6] = 4 + l;
    pkt.add((cip >> 8) & 0xFF);
    pkt.add(cip & 0xFF);
    pkt.add(0x03);
    pkt.addAll(bytes);
    return Uint8List.fromList(pkt);
  }

  // ===================== 工具方法 =====================

  String _subKey(String sigtype, int join, String direction) =>
      '$sigtype:$join:$direction';

  bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 复用基类统一的字节→十六进制格式化
  String _hex(List<int> data) =>
      data.map((b) => BaseConnection.hexByte(b)).join(' ');

  // ===================== 4 系列安全认证（SCIP 0x0B 登录） =====================
  // 标准 SCIP 登录已在握手阶段通过 [_buildLoginPacket]/[_sendLoginPacket] 实现：
  //   TLS 连上后客户端发 0x0B 登录包(username:password)，CP4 回 0x0C 表示成功。
  // 下方 [_handleAuthChallenge] 仅作为“未知包类型”的兜底记录，供个别固件变体联调；
  // 它不会主动发送任何帧（[_sendAuthResponse] 仅打印），不影响 0x0B 主流程。

  /// 解析 CIP 注册结果（0x02 帧 payload）并给出可读原因。
  /// 常见 reject reason codes（参考 Crestron CIP 逆向文档）：
  ///   0x40 = Generic / Server Reject（IP-ID 未在 SIMPL 程序中定义 / 已被占用 / 需先认证）
  ///   0x41 = Out of resources
  ///   0x42 = Slot error
  ///   0x43 = Unreachable
  String _explainReject(List<int> payload) {
    if (payload.isEmpty) return '';
    // payload 末尾的 reject code 是 5 字节布局中的第 4 个字节
    //   layout: [ipid_hi, ipid_mid, ipid_lo, reject_code, 0x1F]
    final int reject = payload.length >= 4 ? payload[payload.length - 2] : 0;
    switch (reject) {
      case 0x40:
        if (_config.cipSecure) {
          return '\n   原因：注册被拒（0x40，SCIP 加密模式）。最可能：CP4 启用了身份验证但 App 未通过挑战-应答，'
              '注册包被拒。\n   建议：① 在 CP4 控制台进入 System Info → Networked Devices → CIP Identity Settings，'
              '临时把 "Require Authentication" 关掉或勾选 "Allow Anonymous Access"，再重试；'
              '② 或者在 App 配置页中控主机区填写 CIP 用户名/密码（需要 CP4 端先抓包确认 challenge 格式才能生效）；'
              '③ 确认 App 端 IP-ID 0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()} '
              '在 SIMPL 程序中已分配给 XPanel/Control System。';
        }
        return '\n   原因：注册被拒（0x40，明文 CIP）。可能：① SIMPL 程序里没有把 IP-ID '
            '0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()} '
            '分配给 XPanel/Control System；② IP-ID 已被其他 client 占用。';
      case 0x41:
        return '\n   原因：处理器资源不足（0x41）';
      case 0x42:
        return '\n   原因：槽位错误（0x42）';
      case 0x43:
        return '\n   原因：目标不可达（0x43）';
      default:
        return '\n   原因：未知 reject code 0x${reject.toRadixString(16)}';
    }
  }

  void _handleAuthChallenge(int type, Uint8List payload) {
    final String log =
        'AUTH type=0x${type.toRadixString(16)}: ${_hex(payload)}';
    debugPrint('[Cip] $log');
    _authLog.add(log);
    if (_authLog.length > 50) _authLog.removeAt(0);
    notifyListeners();
    // TODO(验证): 真实固件下，需从 payload 解析出 challenge 字节与用户名，
    // 下方以整包 payload 作为占位 challenge 触发认证回传，仅供联调。
    if (_config.cipSecure && _config.cipUsername.isNotEmpty) {
      _sendAuthResponse(
        challenge: payload,
        username: _config.cipUsername,
        password: _config.cipPassword,
      );
    }
  }

  /// 计算认证响应哈希（需以真实抓包校准）
  /// 社区常见做法：sha256(password + challenge) 的十六进制串。
  /// 若实际固件为 sha256(challenge + ':' + username + ':' + password)
  /// 或 HMAC，请在此处替换。
  List<int> _computeAuthResponse({
    required List<int> challenge,
    required String username,
    required String password,
  }) {
    final List<int> input = <int>[...password.codeUnits, ...challenge];
    final crypto.Digest digest = crypto.sha256.convert(input);
    return digest.bytes.toList();
  }

  /// 发送认证响应（帧格式需以真实抓包校准，此处为占位）
  void _sendAuthResponse({
    required List<int> challenge,
    required String username,
    required String password,
  }) {
    final List<int> response = _computeAuthResponse(
      challenge: challenge,
      username: username,
      password: password,
    );
    debugPrint('[Cip] 发送认证响应 (username=$username, hash=${_hex(response)})');
    // TODO(验证): 按固件要求的帧结构封装 username + response 并 _send(...)
  }

  /// 安全认证调试日志（UI 可展示）
  List<String> get authLog => List.unmodifiable(_authLog);

  /// 最近事件日志（UI 可展示）
  List<String> get eventLog => List.unmodifiable(_eventLog);
}
