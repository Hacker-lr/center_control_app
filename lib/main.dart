import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/device_connection.dart';
import 'services/video_matrix_connection.dart';
import 'services/camera_connection.dart';
import 'services/crestron_cip_connection.dart';
import 'services/device_config.dart';
import 'pages/power_control_page.dart';
import 'pages/big_screen_page.dart';
import 'pages/video_matrix_page.dart';
import 'pages/camera_control_page.dart';
import 'pages/crestron_page.dart';
import 'pages/system_config_page.dart';

/// ============================================================
/// 中控系统应用入口
/// 按需连接策略：进入页面建立连接，离开释放资源
/// ============================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CenterControlApp());
}

/// ============================================================
/// 应用根组件
/// ============================================================
class CenterControlApp extends StatelessWidget {
  const CenterControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '欢迎使用中控系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // 全局字体改为黑体（SimHei）；所有未显式指定 fontFamily 的文字均继承此设置
        fontFamily: 'SimHei',
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF1F4068),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1F4068),
          secondary: Color(0xFF3A5A8C),
          surface: Color(0xFF161B22),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1117),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MainPage(),
    );
  }
}

/// ============================================================
/// 页面条目描述类
/// ============================================================
class _PageEntry {
  final IconData icon;
  final String label;
  final Widget page;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _PageEntry({
    required this.icon,
    required this.label,
    required this.page,
    required this.onConnect,
    required this.onDisconnect,
  });
}

/// ============================================================
/// 主页面（底部导航栏 + 页面切换）
/// ============================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);

  /// 记录上一次的 Crestron 双模式状态，用于检测开关变化以连接/断开全局 CIP
  bool _crestronModeActive = false;

  /// 记录上一次 CIP 连接身份配置，用于检测凭据/IP-ID/端口等变化后自动重连
  String _cipHost = '';
  int _cipPort = 0;
  int _cipIpId = 0;
  bool _cipSecure = false;
  String _cipUsername = '';
  String _cipPassword = '';

  void _captureCipIdentity() {
    _cipHost = _config.cipHost;
    _cipPort = _config.cipPort;
    _cipIpId = _config.cipIpId;
    _cipSecure = _config.cipSecure;
    _cipUsername = _config.cipUsername;
    _cipPassword = _config.cipPassword;
  }

  final DeviceConfig _config = DeviceConfig();
  final DeviceConnection _deviceConnection = DeviceConnection.timingPower;
  final DeviceConnection _ledPowerConnection = DeviceConnection.ledPower;
  final DeviceConnection _bigScreenConnection = DeviceConnection.bigScreen;
  final VideoMatrixConnection _matrixConnection = VideoMatrixConnection();
  final CameraConnectionManager _cameraManager = CameraConnectionManager();
  final CrestronCipConnection _cipConnection = CrestronCipConnection();

  /// 页面选择导航按钮的入站 join 订阅令牌（中控模式：中控置某页 join 为高 → App 切页）
  final List<String> _pageSelectSubTokens = [];

  /// 根据当前配置动态构建页面列表
  /// 每次调用都会重新读取 DeviceConfig 中的显示开关状态
  /// 这样配置页面修改开关后，返回主页面能立即生效
  List<_PageEntry> _buildPageEntries() {
    final List<_PageEntry> entries = [];

    if (_config.showPowerControl) {
      entries.add(
        _PageEntry(
          icon: Icons.bolt,
          label: '电源控制',
          page: const PowerControlPage(),
          onConnect: _config.crestronMode
              ? () {}
              : () {
                  _deviceConnection.connect();
                  _ledPowerConnection.connect();
                },
          onDisconnect: _config.crestronMode
              ? () {}
              : () {
                  _deviceConnection.disconnect();
                  _ledPowerConnection.disconnect();
                },
        ),
      );
    }

    if (_config.showBigScreen) {
      entries.add(
        _PageEntry(
          icon: Icons.tv,
          label: '大屏控制',
          page: const BigScreenPage(),
          onConnect: _config.crestronMode
              ? () {}
              : () {
                  _bigScreenConnection.connect();
                  _matrixConnection.connect();
                },
          onDisconnect: _config.crestronMode
              ? () {}
              : () {
                  _bigScreenConnection.disconnect();
                  _matrixConnection.disconnect();
                },
        ),
      );
    }

    if (_config.showVideoMatrix) {
      entries.add(
        _PageEntry(
          icon: Icons.videocam_outlined,
          label: '视频矩阵',
          page: const VideoMatrixPage(),
          onConnect: _config.crestronMode
              ? () {}
              : () => _matrixConnection.connect(),
          onDisconnect: _config.crestronMode
              ? () {}
              : () => _matrixConnection.disconnect(),
        ),
      );
    }

    if (_config.showCameraControl) {
      entries.add(
        _PageEntry(
          icon: Icons.videocam,
          label: '摄像头',
          page: const CameraControlPage(),
          onConnect: _config.crestronMode
              ? () {}
              : () => _cameraManager.connectCamera(1), // 进入页面时默认连接第1个摄像头
          onDisconnect: _config.crestronMode
              ? () {}
              : () => _cameraManager.disconnectAll(), // 离开页面时断开所有摄像头
        ),
      );
    }

    // Crestron 控制页仅在【中控(VTP)模式开启】且【显示开关打开】时可见。
    // VTP 关闭（普通直连模式）时无论 showCrestronControl 是否为 true 都不显示，
    // 因为该页本质是 CIP/VTP 控制页，直连模式下无对应功能。
    if (_config.showCrestronControl && _config.crestronMode) {
      entries.add(
        _PageEntry(
          icon: Icons.memory,
          label: 'Crestron',
          page: const CrestronPage(),
          // Crestron 模式下 CIP 由全局统一管理，本页不再重复开关
          onConnect: _config.crestronMode
              ? () {}
              : () => _cipConnection.connect(),
          onDisconnect: _config.crestronMode
              ? () {}
              : () => _cipConnection.disconnect(),
        ),
      );
    }

    return entries;
  }

  /// 页面选择导航按钮对应的数字 join 号（中控模式）
  /// 仅【显示中】的页面参与：join = 基址 + 可见序号（可见序号从 0 开始，
  /// 按页面在导航栏出现的顺序递增），隐藏页面不占号。
  int _pageSelectJoin(int visibleIndex) =>
      _config.joinPageSelectBase + visibleIndex;

  /// 刷新"页面选择"入站 join 订阅（中控模式）
  /// - 清空旧订阅，避免页面显隐/基址变化后串号
  /// - 仅在中控模式为每个可见页订阅 [基址 + 可见序号] 的入站数字 join：
  ///   中控将该 join 置高 → App 切到对应页面（与"点击导航按钮"等效，双向同步）
  void _refreshPageSelectSubscriptions() {
    for (final String t in _pageSelectSubTokens) {
      _cipConnection.unsubscribe(t);
    }
    _pageSelectSubTokens.clear();

    if (!_config.crestronMode) return;

    final int count = _pageCount;
    for (int i = 0; i < count; i++) {
      final int capturedIndex = i; // 捕获当前可见序号，避免闭包拿到错误值
      final String token = _cipConnection.subscribe(
        'd',
        _pageSelectJoin(i),
        (String sig, int join, dynamic value) {
          // 仅响应"按下"边沿（join=1/true），切到对应页面
          if (value == 1 || value == true) {
            _switchToPage(capturedIndex);
          }
        },
        direction: 'in',
      );
      _pageSelectSubTokens.add(token);
    }
  }


  List<_PageEntry> get _pageEntries => _buildPageEntries();
  int get _pageCount => _pageEntries.length;

  /// DeviceConfig 配置变化监听器
  /// 用于在配置页面修改开关后，返回主页面时自动刷新页面列表
  void _onConfigChanged() {
    if (!mounted) return;

    // 每次配置变化（含中控模式开关、页面显隐、页面选择基址、加载完成）都重建
    // "页面选择"入站 join 订阅：清空旧订阅，按当前可见页集合重新订阅，避免串号
    _refreshPageSelectSubscriptions();

    // 检测 Crestron 双模式开关变化：开启则全局连接 CIP，关闭则断开并恢复当前页直连
    // 注意：配置从 SharedPreferences 异步恢复完成时也会走到这里
    // （App 重启后 crestronMode=true 的场景依赖此分支建立全局 CIP 连接）
    if (_config.crestronMode != _crestronModeActive) {
      _crestronModeActive = _config.crestronMode;
      // 先捕获当前已加载的真实 CIP 身份，供下方「身份变化检测」做基准对比。
      // 否则首屏时缓存的 _cipHost 等仍为初始空值，会被误判为"变化"从而
      // 触发多余的 disconnect+connect，导致启动时出现重复建连/双会话。
      if (_crestronModeActive) _captureCipIdentity();
      if (_crestronModeActive) {
        // 切入中控模式：先断开启动早期可能已按“直连模式”建立的设备连接，
        // 避免它们在后台反复重连刷错误日志
        _deviceConnection.disconnect();
        _ledPowerConnection.disconnect();
        _bigScreenConnection.disconnect();
        _matrixConnection.disconnect();
        _cameraManager.disconnectAll();
        _cipConnection.connect();
      } else {
        // 切回普通直连模式：断开 CIP，立即按最新配置重建并连接各直连设备，
        // 无需保存即可生效（修复“关 VTP 后要点保存摄像头才连上”的问题）
        _cipConnection.disconnect();
        // 摄像头连接实例固化于构造时，必须用 rebuild() 按最新配置重建后连接
        _cameraManager.rebuild();
        if (_config.showPowerControl) {
          _deviceConnection.connect();
          _ledPowerConnection.connect();
        }
        if (_config.showBigScreen) {
          _bigScreenConnection.connect();
        }
        if (_config.showVideoMatrix) {
          _matrixConnection.connect();
        }
        if (_config.showCameraControl) {
          _cameraManager.connectCamera(1);
        }
      }
    }

    // 已处于中控模式时，若 CIP 连接身份相关配置发生变化（用户名/密码/IP-ID/
    // 端口/加密开关等），自动重连以应用新凭据，无需手动开关 VTP 模式
    if (_crestronModeActive) {
      if (_cipHost != _config.cipHost ||
          _cipPort != _config.cipPort ||
          _cipIpId != _config.cipIpId ||
          _cipSecure != _config.cipSecure ||
          _cipUsername != _config.cipUsername ||
          _cipPassword != _config.cipPassword) {
        _captureCipIdentity();
        _cipConnection.disconnect();
        _cipConnection.connect();
      }
    }

    // 确保当前索引在有效范围内
    final int count = _pageCount;
    if (count == 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    if (_currentIndex >= count) {
      // 当前索引超出范围，自动调整到最后一页
      final int newIndex = count - 1;
      _pageEntries[newIndex].onConnect();
      setState(() => _currentIndex = newIndex);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(newIndex);
      }
    } else {
      // 索引有效，仅刷新界面
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    // 注册配置变化监听器，配置页面修改后返回时能自动刷新
    _config.addListener(_onConfigChanged);
    // 记录初始双模式状态（此时持久化配置可能尚未异步加载，先按默认值占位，
    // 真正的模式判定在配置加载完成后的 _onConfigChanged 中处理）
    _crestronModeActive = _config.crestronMode;
    if (_pageCount == 0) {
      debugPrint('[主页面] 警告：没有启用的页面！请在 DeviceConfig 中设置 showXxx = true');
      return;
    }
    // Crestron 双模式下，全局维持 CIP 连接，使任意页面的按钮都能发 join
    if (_crestronModeActive) {
      _cipConnection.connect();
    }
    // 关键修复：CameraConnectionManager 构造时把摄像头列表按【默认值】固化，
    // 而持久化配置（真实 IP/端口/协议）是异步从 SharedPreferences 加载的。
    // 若不等配置加载完成就连接，会连上默认的 TCP 摄像头而连不上，
    // 表现为“一直重连连不上”，必须手动点保存触发 rebuild 才恢复。
    // 因此这里先 await 配置加载，再按真实配置 rebuild 摄像头连接列表；
    // 之后首帧 onConnect 会用真实配置连接（进入摄像头页即连上正确设备）。
    _config.ensureLoaded().then((_) {
      if (!mounted) return;
      _cameraManager.rebuild();
      // 兜底：确保异步加载完成后（页面集合/基址已确定）订阅一次页面选择入站 join。
      // 正常情况下 _onConfigChanged（加载完成 notifyListeners）已重建订阅，此处防止遗漏。
      _refreshPageSelectSubscriptions();
      // 配置异步加载完成后，CIP 全局连接由 _onConfigChanged（DeviceConfig 加载
      // 完成时的 notifyListeners 触发）统一建立，无需在此重复 connect，
      // 否则会与 _onConfigChanged 的建连叠加，造成启动时重复建连/双会话。
      // 等首帧布局完成后再触发当前页 onConnect（摄像头此时已用真实配置就绪）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageEntries[_currentIndex].onConnect();
      });
    });
  }

  void _switchToPage(int newIndex) {
    if (_currentIndex == newIndex || newIndex < 0 || newIndex >= _pageCount) {
      return;
    }

    _pageEntries[_currentIndex].onDisconnect();
    _pageEntries[newIndex].onConnect();

    setState(() => _currentIndex = newIndex);

    // 中控模式：点击页面选择导航按钮 → 脉冲该页面对应的数字 join（基址 + 可见序号），
    // 向中控上报"用户切到了第 N 页"。中控置同一 join 为高也会经订阅回调走到这里（双向同步）。
    if (_config.crestronMode) {
      _cipConnection.pulse(_pageSelectJoin(newIndex));
    }

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutExpo,
      );
    }
  }

  @override
  void dispose() {
    // 移除页面选择入站 join 订阅，避免回调访问已销毁的 State
    for (final String t in _pageSelectSubTokens) {
      _cipConnection.unsubscribe(t);
    }
    _pageSelectSubTokens.clear();
    // 移除配置变化监听器，避免内存泄漏
    _config.removeListener(_onConfigChanged);
    _pageController.dispose();
    if (_pageCount > 0 && _currentIndex < _pageCount) {
      _pageEntries[_currentIndex].onDisconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageCount == 0) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text(
            '没有启用的控制页面\n请在 DeviceConfig 中设置 showXxx = true',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        allowImplicitScrolling: true,
        children: _pageEntries.asMap().entries.map((entry) {
          final int index = entry.key;
          return AnimatedBuilder(
            key: ObjectKey(entry.value.page),
            animation: _pageController,
            builder: (context, child) {
              // 根据页面滚动进度计算当前页与相邻页的相对偏移量
              final double page = _pageController.page ?? index.toDouble();
              final double offset = (page - index).abs();
              // 新页进入时从 0.96 轻微放大到 1.0，同时淡入；离开页反向收小并淡出
              final double scale = (1.0 - offset * 0.04).clamp(0.92, 1.0);
              final double opacity = (1.0 - offset * 0.3).clamp(0.7, 1.0);
              return Transform.scale(
                scale: scale,
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: entry.value.page,
          );
        }).toList(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: GestureDetector(
        onLongPress: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 550),
              reverseTransitionDuration: const Duration(milliseconds: 450),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const SystemConfigPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    // 进场：从下方明显滑入(1/4屏) + 轻微放大浮现 + 平缓渐显，避免对全屏页面而言太微弱；返回时自动反向
                    final slide =
                        Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: slide,
                        child: ScaleTransition(scale: scale, child: child),
                      ),
                    );
                  },
            ),
          );
        },
        child: const Text(
          '欢迎使用中控系统',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD4C5A9),
            letterSpacing: 2.0,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFF30363D), height: 0.5),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D), width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_pageCount, (index) {
              final entry = _pageEntries[index];
              return _buildNavItem(entry.icon, entry.label, index);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _switchToPage(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1F4068).withAlpha(60)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF6B9BD2) : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFFD4C5A9) : Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
