import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/device_connection.dart';
import 'services/matrix_connection.dart';
import 'pages/power_control_page.dart';
import 'pages/video_matrix_page.dart';

/// ============================================================
/// 中控系统应用入口
/// 功能概述：
/// 1. 按需连接策略：进入某设备控制页时建立连接，离开时释放资源
/// 2. 每分钟心跳检测，断连自动重连
/// 3. 两页面布局：电源控制页 + 视频矩阵控制页
/// 4. 底部导航栏切换页面，切换时按钮高亮，页面切换带平滑动画
/// ============================================================
void main() {
  // 确保Flutter框架初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定应用为竖屏模式（控制类应用推荐竖屏使用）
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 设置系统状态栏样式（深色背景配浅色图标）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,   // 状态栏透明
      statusBarIconBrightness: Brightness.light, // 浅色图标
      systemNavigationBarColor: Color(0xFF0D1117), // 底部导航栏深色
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 启动应用
  runApp(const CenterControlApp());
}

/// ============================================================
/// 应用根组件
/// 定义全局深色沉稳主题，组装页面结构
/// ============================================================
class CenterControlApp extends StatelessWidget {
  const CenterControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 应用标题（在Android任务列表中可见）
      title: '欢迎使用中控系统',

      // 关闭右上角Debug横幅
      debugShowCheckedModeBanner: false,

      // ---- 全局主题定义 ----
      // 采用深色沉稳风格：深蓝灰背景 + 低饱和度配色 + 香槟金点缀
      theme: ThemeData(
        // 深色模式
        brightness: Brightness.dark,

        // 主背景色：极深蓝灰
        scaffoldBackgroundColor: const Color(0xFF0D1117),

        // 主色调：沉稳蓝
        primaryColor: const Color(0xFF1F4068),

        // 完整配色方案
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1F4068),
          secondary: Color(0xFF3A5A8C),
          surface: Color(0xFF161B22),
        ),

        // AppBar全局样式（无阴影，标题居中）
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1117),
          elevation: 0,
          centerTitle: true,
        ),

        // 使用系统默认字体
        fontFamily: null,
      ),

      // 首页路由
      home: const MainPage(),
    );
  }
}

/// ============================================================
/// 主页面（底部导航栏 + 页面切换）
/// 按需连接策略：仅在当前页面停留时连接对应设备，切换页面时释放旧设备资源
/// 整体布局：顶部标题栏 + 中间可切换内容区 + 底部导航菜单栏
/// 页面切换使用PageView实现平滑滑动动画
/// ============================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // ---------- 页面索引 ----------
  // 0 = 电源控制页，1 = 视频矩阵页
  int _currentIndex = 0;

  // ---------- PageView控制器（用于实现页面切换动画） ----------
  final PageController _pageController = PageController(initialPage: 0);

  // ---------- 页面实例列表 ----------
  // 通过PageView自动维护两个页面的状态
  final List<Widget> _pages = const [
    PowerControlPage(),
    VideoMatrixPage(),
  ];

  // ---------- 设备连接服务 ----------

  /// 时序电源设备连接
  final DeviceConnection _deviceConnection = DeviceConnection();

  /// 视频矩阵设备连接
  final MatrixConnection _matrixConnection = MatrixConnection();

  @override
  void initState() {
    super.initState();
    // 按需连接策略：启动时只连接默认首页（电源控制页，index=0）的设备
    // 延迟到首帧渲染完成后执行，避免在构建期间进行异步操作
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectDeviceAtIndex(0);
    });
  }

  /// ============================================================
  /// 按需连接策略：连接到指定索引页面对应的设备
  /// 通用方法，后续新增设备页面只需在此方法中添加映射关系
  /// [index] 页面索引（0=电源控制, 1=视频矩阵）
  ///
  /// 后续扩展示例：
  ///   case 2: _newDeviceConnection.connect();  // 新增设备
  /// ============================================================
  void _connectDeviceAtIndex(int index) {
    switch (index) {
      case 0:
        // 进入电源控制页 → 连接时序电源设备
        _deviceConnection.connect();
        break;
      case 1:
        // 进入视频矩阵页 → 连接视频矩阵设备
        _matrixConnection.connect();
        break;
      // [开发者扩展处] 添加新设备页面时在此补充 case
      // case 2: _someNewConnection.connect(); break;
    }
  }

  /// ============================================================
  /// 按需连接策略：断开指定索引页面对应的设备连接，释放资源
  /// [index] 页面索引（0=电源控制, 1=视频矩阵）
  ///
  /// 后续扩展示例：
  ///   case 2: _newDeviceConnection.disconnect();  // 新增设备
  /// ============================================================
  void _disconnectDeviceAtIndex(int index) {
    switch (index) {
      case 0:
        // 离开电源控制页 → 断开时序电源设备，释放Socket和心跳定时器
        _deviceConnection.disconnect();
        break;
      case 1:
        // 离开视频矩阵页 → 断开视频矩阵设备，释放Socket和心跳定时器
        _matrixConnection.disconnect();
        break;
      // [开发者扩展处] 添加新设备页面时在此补充 case
      // case 2: _someNewConnection.disconnect(); break;
    }
  }

  /// ============================================================
  /// 页面切换核心方法（按需连接策略）
  /// 执行顺序：断开旧设备 → 连接新设备 → 动画切换页面
  /// [newIndex] 目标页面的索引
  /// ============================================================
  void _switchToPage(int newIndex) {
    // 如果目标页与当前页相同，不做任何操作
    if (_currentIndex == newIndex) return;

    // 第一步：断开当前设备的连接，释放网络资源（Socket + 心跳定时器）
    _disconnectDeviceAtIndex(_currentIndex);

    // 第二步：连接到新页面对应的设备并启动心跳
    _connectDeviceAtIndex(newIndex);

    // 第三步：更新当前页面索引（触发底部导航栏高亮切换）
    setState(() {
      _currentIndex = newIndex;
    });

    // 第四步：执行PageView平滑滑动动画切换页面
    _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    // 释放PageView控制器
    _pageController.dispose();

    // 断开当前页面设备的连接（按需策略：退出时仅释放当前设备）
    _disconnectDeviceAtIndex(_currentIndex);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---- 顶部标题栏 ----
      appBar: AppBar(
        title: const Text(
          '欢迎使用中控系统',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD4C5A9), // 香槟金色标题 - 沉稳而优雅
            letterSpacing: 2.0,       // 字间距增大，更显大气
          ),
        ),
        // 标题栏底部细线分隔
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF30363D), // 深灰分割线
            height: 0.5,
          ),
        ),
      ),

      // ---- 中间内容区 ----
      // 使用PageView实现页面间的平滑滑动动画
      // physics设为NeverScrollable禁用手指滑动（仅通过底部按钮切换）
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        // 预渲染相邻页面以保证切换流畅
        allowImplicitScrolling: true,
        children: _pages,
      ),

      // ---- 底部导航菜单栏 ----
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  /// ============================================================
  /// 构建底部导航菜单栏
  /// 包含"电源控制"和"视频矩阵"两个切换按钮
  /// 当前选中按钮以香槟金色高亮显示，点击时按需连接+动画切换
  /// ============================================================
  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22), // 深色面板背景
        border: Border(
          top: BorderSide(
            color: Color(0xFF30363D), // 顶部分割线
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            // 按钮均匀分布
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ---- 电源控制导航按钮 ----
              _buildNavItem(
                icon: Icons.bolt,
                label: '电源控制',
                index: 0,
              ),

              // ---- 视频矩阵导航按钮 ----
              _buildNavItem(
                icon: Icons.videocam_outlined,
                label: '视频矩阵',
                index: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// 构建单个底部导航项
  /// [icon]  导航按钮图标
  /// [label] 导航按钮文字标签
  /// [index] 对应页面的索引（0=电源控制, 1=视频矩阵）
  ///
  /// 选中状态：图标为柔和蓝色 + 文字香槟金色 + 背景半透明蓝色
  /// 点击行为：调用 _switchToPage 执行按需连接策略 + 动画切换
  /// ============================================================
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    // 判断当前项是否为选中状态
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        // 点击导航按钮 → 断开旧设备 + 连接新设备 + 动画切换页面
        _switchToPage(index);
      },
      // 确保点击区域覆盖整个按钮
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          // 选中时添加半透明蓝色背景
          color: isSelected
              ? const Color(0xFF1F4068).withAlpha(60)
              : Colors.transparent,
          // 圆角背景
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- 按钮图标 ----
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? const Color(0xFF6B9BD2) // 选中：柔和蓝色
                  : Colors.grey[600],        // 未选中：灰色
            ),
            const SizedBox(width: 8),

            // ---- 按钮文字标签 ----
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFFD4C5A9) // 选中：香槟金
                    : Colors.grey[600],        // 未选中：灰色
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
