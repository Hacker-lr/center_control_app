import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
///     连接 → 处理器发 0x0F(Who-Is / 注册请求)
///          → 客户端回 0x01(旧版 Client Sign-On 注册包，含 IP-ID)
///          → 处理器回 0x02(Conn-Accepted，成功 = 00 00 00 1F)
///          → 客户端发 0x05(update request) → 处理器回 0x1C → 0x1D + 心跳
///
///   SCIP（4 系列 / 41796 加密，开启身份验证）：
///     TLS 连接 → 客户端先发 0x0B 登录包(username:password)
///             → 处理器回 0x0C(成功 = 00 00 01)
///             → 处理器发 0x0F(Who-Is / 注册请求)
///             → 客户端回 0x0A(Client Sign-On 注册包，含 IP-ID)
///             → 处理器回 0x02(Conn-Accepted，成功 = 00 00 00 1F)
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

  /// 安全探活定时器（替代被 CP4 拒绝的 0x0D 心跳 ping）：
  /// 周期性发送合法的 update request(0x05)，CP4 收到后会回 0x1C/0x1D 状态推送，
  /// 从而刷新 [_lastHeartbeatResponse]；写失败(onError)秒级触发断连，
  /// 链路静默断则看门狗(deadline 超时)兜底。
  Timer? _probeTimer;

  /// 探活发送间隔（秒）。需明显小于 [_kProbeDeadlineSeconds]，保证至少收到 1~2 次回复。
  static const int _kProbeIntervalSeconds = 3;

  /// 静默断链判定阈值（秒）：距上次收到任何数据超过该值即判定链路已死。
  /// 取 2 倍探活间隔（6 = 2×3）：CP4 即便偶发漏回一次 update request（TCP 不会丢包，
  /// 多半是端侧瞬时繁忙），下一个 3 秒周期内的回复仍能在 6 秒阈值内刷新时间戳，
  /// 不会误杀；仅当连续 2 个周期（>6 秒）完全无回包才判定真断链。
  /// 比此前纯 TCP 层 30 秒才感知、以及旧参数(间隔6/阈值18，最坏~24秒)都快很多。
  static const int _kProbeDeadlineSeconds = 6;

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

  /// SCIP 登录包(0x0B)是否已发送，避免重复发送
  bool _loginSent = false;

  /// SCIP 0x0C 登录是否已被服务器确认（收到成功码 00 00 01）。
  /// 用于解决竞态：部分 CP4 固件会先发 0x0F(注册请求) 后发 0x0C(登录确认)，
  /// 若此时立即回应注册包会被以 0x40 拒绝（未认证）。故注册包须等 0x0C 到达后再发。
  bool _loginConfirmed = false;

  // ===================== 基类抽象属性实现 =====================

  @override
  String get deviceIp => _config.cipHost;

  @override
  int get devicePort => _config.cipPort;

  @override
  bool get useTcp => true;

  /// CIP 不发送 0x0D 心跳 ping：Crestron CP4 不兼容该简单 ping，收到即断开连接
  /// （早期日志实证：心跳#1 → Socket已关闭）。连接保持靠 TCP 层即可，CP4 会在
  /// join 状态变化时主动推送，无需客户端轮询 ping。置空即不发送任何心跳包。
  @override
  String get heartbeatCommand => '';

  /// CIP 空闲时 CP4 不主动发数据是正常行为，看门狗「无数据超时」会误杀正常连接，
  /// 故禁用；仅依赖 TCP 层断连(onDone/onError)触发自动重连（与官方 Crestron App 一致）。
  @override
  bool get enableLivenessWatchdog => false;

  /// CIP 永不发送心跳 ping（CP4 收到 0x0D 即断开连接）。
  @override
  bool get autoStartHeartbeatPings => false;

  @override
  bool get sendAsHex => true;

  /// CIP 不发送心跳 ping（详见上方 [heartbeatCommand]），故这两个基类参数当前不生效：
  /// 真实保活由 [_kProbeIntervalSeconds]/[_kProbeDeadlineSeconds] 驱动的 0x05 探活定时器完成。
  /// 此处保留重写仅作"若将来为 CIP 启用基类看门狗/心跳"时的预留值，日常阅读请勿误以为 CIP 在发心跳。
  @override
  int get heartbeatInterval => 2;

  /// 见 [heartbeatInterval]：CIP 当前不发送心跳，此倍数不生效，由 [_kProbeDeadlineSeconds] 兜底判定静默断链。
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
    _loginConfirmed = false;
    _setCipConnected(false);
    _logEvent('TCP 已连接 $deviceIp:$devicePort，等待处理器注册请求(0x0F)...');
    // 诊断日志：打印实际生效的配置值，便于排查「IP-ID/凭据不对却仍被拒」类问题
    _logEvent(
      '配置快照: cipSecure=${_config.cipSecure}, '
      'IP-ID=0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()}, '
      'user=${_config.cipUsername.isEmpty ? '<空>' : _config.cipUsername}, '
      'passLen=${_config.cipPassword.length}',
    );
    // ⚠️ SCIP（4 系列加密）模式：对齐官方 Crestron App 实测握手顺序——
    //   CP4 连上即主动发 0x0F；客户端回 0x0A 注册(被 0x40 拒)→ 再发 0x0B 登录
    //   → CP4 回 0x0C 即判定连接就绪。**不在连接时发 0x0B**（避免顺序错乱），
    //   0x0B 仅在 0x02 收到 0x40 拒绝时由失败分支补发（见 case 0x02）。
    //   握手完成后的 0x05 探活由 _setCipConnected 触发（见 [_setCipConnected]），
    //   防止握手未完成就发 0x0D 被 CP4 当乱包断开。
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
    _stopProbe();
    _rxBuffer.clear();
    _loginSent = false;
    _loginConfirmed = false;
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
        // SCIP 登录响应：CP4 仅在登录成功时回 0x0C（官方抓包实测 0C 00 03 00 00 00，
        // scip2cip 记为 0C 00 03 00 00 01；两种成功码均视为通过）。
        // ⚠️ 关键：官方 Crestron App 收到 0x0C 即认为连接就绪，并不等待
        // end-of-query(0x1C)。旧逻辑死等 0x1C 导致 isCipConnected 永远为 false、
        // 控制页无法发指令、且与 crestron 页状态打架。故此处直接判定连接成功。
        _loginConfirmed = true;
        _setCipConnected(true);
        _logEvent('✓ SCIP 登录成功(0x0C)，连接就绪（CIP 应用层握手完成）');
        break;
      case 0x0F:
        // 服务器注册请求 → 回应注册包(0x0A，含 IP-ID)。
        // 注意：登录包(0x0B)在此**不**发送——对齐官方 App 实测顺序：
        //   0x0F → 发 0x0A（被 0x40 拒）→ 0x02 分支补发 0x0B → 收 0x0C。
        // 只有「先注册(未认证)再被拒」才能触发 CP4 走完登录流程。
        final Uint8List reg = _buildRegistration(_config.cipIpId);
        _logEvent(
          '收到注册请求(0x0F)，payload=${_hex(payload)}',
        );
        _logEvent(
          '发送 IP-ID 0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()} 注册包 [${_hex(reg)}]',
        );
        _send(reg);
        break;
      case 0x02:
        // 注册结果（参考 python-cipclient 逐字节精确判定，避免把 reject 误判为成功）
        //   成功         = ...00 1F（结尾两字节为 00 1F；标准 4 字节 = 00 00 00 1F，
        //                          亦兼容可能的 5 字节 SCIP 变体 ...00 00 1F）
        //   IP-ID 不存在 = FF FF 02（3 字节，无 0x1F 结尾）
        //   其它（含 00 00 40 1F 等 reject 码）均为失败
        // ⚠️ 注意：1F 只是成功帧的固定结尾字节，reject 帧（如 00 00 40 1F）末尾同样为 1F，
        //    不能单凭“末尾 == 1F”判定成功——否则会把被拒注册误判为成功，
        //    接着发 update request，CP4 因我们并未真正注册成功而回 0x03 断开 → 反复重连。
        _logEvent('收到注册结果(0x02): [${_hex(payload)}]');
        if (_eq(payload, [0xff, 0xff, 0x02])) {
          _logEvent(
            '✗ IP-ID 0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()} 在处理器上不存在！'
            '请核对 SIMPL 程序中 XPanel 符号的 IP-ID（注意它是十六进制）',
          );
          _failConnection();
        } else if (payload.length >= 2 &&
            payload.last == 0x1f &&
            payload[payload.length - 2] == 0x00) {
          // 成功：结尾两字节为 00 1F（状态字节 0x00 + 结尾标记 0x1F）
          _logEvent('✓ 注册成功，发送 update request');
          _send(_buildUpdateRequest());
        } else {
          _logEvent('✗ 注册失败: [${_hex(payload)}]${_explainReject(payload)}');
          // ⚠️ 不再 _failConnection 死循环重连：官方 App 收到 0x40 后并不断开，
          //   而是保持连接、发出 0x0B 登录，CP4 接受后回 0x0C 即判定就绪。
          //   本实现严格对齐官方顺序：0x0B 登录在此处(0x40 拒绝后)才发，
          //   若已连上或已发过则跳过，避免重复(_sendLoginPacket 有 _loginSent 守卫)。
          if (!_loginSent && !_cipConnected) _sendLoginPacket();
          // 若 IP-ID 确未授权，CP4 不会推进，看门狗超时将正常重连；
          // 每次重连之间给 CP4 留出推进窗口，登录被接受时通常可连上。
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
        // 控制系统中断（处理器主动要求断开）。属传输层/远端事件，
        // 按 python-cipclient 行为重连；记录原始字节便于联调。
        _logEvent('✗ 控制系统中断(0x03) [${_hex(payload)}]，准备重连');
        notifyConnectionError();
        break;
        default:
          // 未知包类型，仅记录原始字节供联调。4 系列注册/登录握手已由
          // 0x0C / 0x0F / 0x02 分支覆盖，CP4 不会发送需要客户端应答的认证挑战，
          // 故无需额外响应（官方 Crestron App 实测亦无 0x04 挑战交互）。
          debugPrint(
            '[Cip] 未处理包类型 0x${type.toRadixString(16)}: ${_hex(payload)}',
          );
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
    if (v) {
      // 握手完成：刷新存活时间戳并启动安全探活（替代被 CP4 拒绝的 0x0D 心跳 ping）。
      // 探活靠「发送合法 update request 让 CP4 回包」驱动，故不再依赖 TCP 层静默感知。
      markAlive();
      _startProbe();
    } else {
      _stopProbe();
    }
  }

  /// 启动安全探活：立即探活一次并周期性发送 update request。
  void _startProbe() {
    _stopProbe();
    _probeTimer = Timer.periodic(
      Duration(seconds: _kProbeIntervalSeconds),
      (_) => _onProbeTick(),
    );
    // 立即探活一次，缩短握手完成后的首个检测空窗
    Timer.run(_onProbeTick);
  }

  /// 停止安全探活
  void _stopProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  /// 探活 tick：发送合法 update request；若距上次收到任何数据超过 deadline，
  /// 判定链路已死（静默断链兜底）。
  void _onProbeTick() {
    if (!_cipConnected) {
      _stopProbe();
      return;
    }
    // 看门狗：静默断链场景（写成功入缓冲但 CP4 不再回包）的兜底判定。
    // 用毫秒 + >= 判定边界，保证正好到达阈值即触发（不漏判、不拖到下一 tick），
    // 且阈值=2 倍间隔，单次漏回不会误杀。
    final DateTime? last = lastHeartbeatResponse;
    if (last != null &&
        DateTime.now().difference(last).inMilliseconds >=
            _kProbeDeadlineSeconds * 1000) {
      _logEvent(
        '探活看门狗：超过 $_kProbeDeadlineSeconds 秒未收到任何数据，判定链路断开',
      );
      reportTransportLost();
      return;
    }
    // 发送合法 update request 探活（CP4 会回 0x1C/0x1D 状态推送，刷新存活时间戳）。
    // 发送失败会经 socket onError → 基类 reportTransportLost 秒级断连。
    try {
      _send(_buildUpdateRequest());
    } catch (e) {
      _logEvent('探活发送异常: $e');
      reportTransportLost();
    }
  }

  /// 协议层硬失败（如注册被拒 / IP-ID 不存在）。
  /// 这类属于配置错误，自动重连没有意义（每次都会以同样原因失败），
  /// 因此停止自动重连并展示明确错误，等待用户在配置页修正凭据/IP-ID后，
  /// 由 main.dart 的 _onConfigChanged 调用 connect() 重置标志并重新连接。
  /// 若直接 reconnect，会出现“连上→被拒→0x03 断开→再连”的死循环刷屏。
  void _failConnection() {
    _setCipConnected(false);
    _logEvent(
      '连接已停止（配置类错误）：请在“中控主机”区核对 IP-ID / 用户名 / 密码，'
      '修正后本页会自动重连',
    );
    // manual=true 阻止基类自动重连；下次 connect() 会清零该标志。
    disconnect(manual: true);
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

  /// 客户端注册（Client Sign-On）。⚠️ 帧类型必须是 0x0A，不是 0x01！
  /// 逐字节核对 node-red-contrib-cip `sendIPID()`（可运行 CIP 客户端）与
  /// scip2cip 转发的官方 Crestron 移动 App 注册帧（其 `data[0]==0x0A`、IP-ID 在 `data[4]`，
  /// 且会把 `data[5:6]` 端口改写成 SCIP 端口）：
  ///   常量：CLIENT_SIGNON=0x0a，SERVER_SIGNON=0x01（0x01 是服务器签名，非客户端）。
  /// 旧实现误用 0x01 + 错误的 IP-ID 位置/后缀，3 系容忍故能连、4 系严格故 0x40 拒绝。
  /// 结构：`0A 00 <len> 00 [ipid] [port_hi] [port_lo] 40 02 00 00 F1 01 <hostname>`
  ///   —— 官方 App 抓包实测尾部为 `F1 01 <hostname>`（hostname 为本机名，官方连代理时用 "localhost"）。
  ///   - ipid 在负载第 2 字节（整帧索引 4）；
  ///   - port 字段 = 本连接目标端口（3 系 41794=0xA342；4 系 SCIP 41796=0xA344）。
  Uint8List _buildRegistration(int ipid) {
    if (_config.cipSecure) {
      // 4 系列 SCIP（加密，41796）：现代 Client Sign-On 帧（0x0A）。
      // 逐字节对齐 node-red-contrib-cip 可运行客户端 sendIPID() 与 scip2cip
      // 截获的官方 Crestron 移动 App 注册帧（其 ForwardClientToSsl 取 ipid=data[4]）：
      //   0a 00 0b 00 00 [ipid] [port_hi] [port_lo] 40 02 00 00 d1 01 00
      // 注意 IP-ID 前必须有一个固定 0x00 占位字节（data[3]=0x00，data[4]=ipid），
      // 旧实现漏掉该 0x00 导致 IP-ID 实际落在 data[3]，与官方包错位。
      // port 字段 = 本连接目标端口（SCIP 41796=0xA344；明文 41794=0xA342）。
      final int port = devicePort;
      // 官方 Crestron App 抓包实测尾部固定为 `F1 01 localhost`（不是真实主机名！）。
      // 用真实主机名会被 CP4 以 0x40 拒绝，必须逐字节对齐官方用固定 "localhost"。
      const String hostName = 'localhost';
      final List<int> hostBytes = hostName.codeUnits.toList();
      final payload = [
        0x00, // 固定占位字节（IP-ID 前的 0x00，官方包结构如此）
        ipid & 0xFF,
        (port >> 8) & 0xFF,
        port & 0xFF,
        0x40,
        0x02,
        0x00,
        0x00,
        0xF1,
        0x01,
        ...hostBytes,
      ];
      return _frame(0x0a, payload);
    }
    // 3 系列明文 CIP（41794）：旧版 Client Sign-On 帧（0x01）。
    // 保持用户原可用配置——3 代处理器认 0x01 旧格式，勿回归为 0x0A。
    final payload = [
      0x00, 0x00, 0x00, 0x00, 0x00,
      ipid & 0xFF,
      0x40, 0xff, 0xff, 0xf1, 0x01,
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
  //   TLS 连上后客户端发 0x0B 登录包(username:password)，CP4 回 0x0C 表示成功，
  //   随后按 0x0F → 0x0A(被 0x40 拒) → 0x0B → 0x0C 顺序完成握手（见各 case 分支）。
  // Crestron 未公开 4 系列 SCIP 的 0x04 客户端认证算法，且官方 App 实测表明在
  // 正确账号/IP-ID 下 CP4 不会发送 0x04 挑战，故本实现不再包含 0x04 探测逻辑。

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
          // 4 系列无法关闭身份验证（Crestron 官方文档明确），所以必须提供正确账号/IP-ID。
          // 已逐字节核对 scip2cip（4 代 SCIP 可运行参考实现）：其 0x0B 登录包与本项目完全一致，
          // 且 0x0C 00 03 00 00 01 即"登录成功"。因此：
          //   - 若曾收到 0x0C 登录成功 → 账号密码被接受，被拒指向 IP-ID；
          //   - 若从未收到 0x0C       → 账号密码未被接受（4 代默认未必是 CRESTRON:CRESTRON）。
          if (_loginConfirmed) {
            return '\n   原因：注册被拒（0x40，SCIP 加密模式）。已收到 0x0C 登录成功，'
                '说明账号密码 "${_config.cipUsername}" 被 CP4 接受；'
                '被拒指向 IP-ID 0x${_config.cipIpId.toRadixString(16).padLeft(2, '0').toUpperCase()}：'
                '\n   ① 未在 SIMPL 程序中把该 IP-ID 分配给 XPanel / Control System 符号；'
                '\n   ② 在 CP4 控制台 System Info → Networked Devices → CIP Identity Settings 中，'
                '该 IP-ID 未对当前账号授权（4 代需显式登记允许连接的 IP-ID）；'
                '\n   ③ 该 IP-ID 已被其它在线客户端占用。';
          }
          return '\n   原因：注册被拒（0x40，SCIP 加密模式）。未收到 0x0C 登录成功，'
              '说明 CP4 未接受账号密码。4 系列身份验证无法关闭，'
              '请确认 App 端 CIP 用户名/密码是 CP4 控制系统的真实账号'
              '（4 代默认未必是 CRESTRON:CRESTRON，以 CP4 实际配置为准）。';
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

  /// 最近事件日志（UI 可展示）
  List<String> get eventLog => List.unmodifiable(_eventLog);
}
