import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/device_connection.dart';
import 'services/matrix_connection.dart';
import 'services/big_screen_connection.dart';
import 'services/camera_connection.dart';
import 'services/device_config.dart';
import 'pages/power_control_page.dart';
import 'pages/big_screen_page.dart';
import 'pages/video_matrix_page.dart';
import 'pages/camera_control_page.dart';
import 'pages/debug_config_page.dart';

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

  final DeviceConfig _config = DeviceConfig();
  final DeviceConnection _deviceConnection = DeviceConnection();
  final BigScreenConnection _bigScreenConnection = BigScreenConnection();
  final MatrixConnection _matrixConnection = MatrixConnection();
  final CameraConnectionManager _cameraManager = CameraConnectionManager();

  /// 根据当前配置动态构建页面列表
  /// 每次调用都会重新读取 DeviceConfig 中的显示开关状态
  /// 这样配置页面修改开关后，返回主页面能立即生效
  List<_PageEntry> _buildPageEntries() {
    final List<_PageEntry> entries = [];

    if (_config.showPowerControl) {
      entries.add(_PageEntry(
        icon: Icons.bolt,
        label: '电源控制',
        page: const PowerControlPage(),
        onConnect: () => _deviceConnection.connect(),
        onDisconnect: () => _deviceConnection.disconnect(),
      ));
    }

    if (_config.showBigScreen) {
      entries.add(_PageEntry(
        icon: Icons.tv,
        label: '大屏控制',
        page: const BigScreenPage(),
        onConnect: () {
          _bigScreenConnection.connect();
          _matrixConnection.connect();
        },
        onDisconnect: () {
          _bigScreenConnection.disconnect();
          _matrixConnection.disconnect();
        },
      ));
    }

    if (_config.showVideoMatrix) {
      entries.add(_PageEntry(
        icon: Icons.videocam_outlined,
        label: '视频矩阵',
        page: const VideoMatrixPage(),
        onConnect: () => _matrixConnection.connect(),
        onDisconnect: () => _matrixConnection.disconnect(),
      ));
    }

    if (_config.showCameraControl) {
      entries.add(_PageEntry(
        icon: Icons.videocam,
        label: '摄像头',
        page: const CameraControlPage(),
        onConnect: () => _cameraManager.connectCamera(1), // 进入页面时默认连接第1个摄像头
        onDisconnect: () => _cameraManager.disconnectAll(), // 离开页面时断开所有摄像头
      ));
    }

    return entries;
  }

  /// 当前页面条目列表（每次build时动态获取，确保配置修改后实时生效）
  List<_PageEntry> get _pageEntries => _buildPageEntries();
  int get _pageCount => _pageEntries.length;

  /// DeviceConfig 配置变化监听器
  /// 用于在配置页面修改开关后，返回主页面时自动刷新页面列表
  void _onConfigChanged() {
    if (!mounted) return;

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
    if (_pageCount == 0) {
      debugPrint('[主页面] 警告：没有启用的页面！请在 DeviceConfig 中设置 showXxx = true');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageEntries[_currentIndex].onConnect();
    });
  }

  void _switchToPage(int newIndex) {
    if (_currentIndex == newIndex || newIndex < 0 || newIndex >= _pageCount) return;

    _pageEntries[_currentIndex].onDisconnect();
    _pageEntries[newIndex].onConnect();

    setState(() => _currentIndex = newIndex);

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
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
          child: Text('没有启用的控制页面\n请在 DeviceConfig 中设置 showXxx = true', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        allowImplicitScrolling: true,
        children: _pageEntries.map((e) => e.page).toList(),
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
            MaterialPageRoute(
              builder: (context) => const DebugConfigPage(),
            ),
          );
        },
        child: const Text(
          '欢迎使用中控系统',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD4C5A9), letterSpacing: 2.0),
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
          color: isSelected ? const Color(0xFF1F4068).withAlpha(60) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: isSelected ? const Color(0xFF6B9BD2) : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? const Color(0xFFD4C5A9) : Colors.grey[600], letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}