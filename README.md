# 中控系统 App (Center Control App)

一个基于 Flutter 开发的跨平台中控系统应用，用于集中控制会议室/展厅中的多种硬件设备，包括时序电源、大屏拼接器、视频矩阵和摄像头。支持 TCP/UDP 双协议通信、设备品牌配置、响应式布局和实时状态同步。

## 功能特性

### 设备控制
- **时序电源控制**：远程开关电源设备，支持 TCP/UDP 协议切换
- **大屏拼接器控制**：切换分屏模式（全屏、二分屏、三分屏、四分屏、五分屏），支持可视化预览
- **视频矩阵控制**：输入/输出通道绑定切换，支持长按通道按钮重命名
- **摄像头控制**：基于 Sony VISCA over IP 协议，支持云台方向控制、变焦、预置位调用/保存

### 系统功能
- **TCP/UDP 双协议支持**：每种设备独立选择通信协议
- **设备品牌配置**：预置多种设备品牌，选择后自动填充协议、端口和控制指令
- **页面显示开关**：通过配置页面控制各功能页面的显示/隐藏
- **长按重命名**：视频矩阵输入/输出通道、摄像头选择按钮、预置位按钮均支持长按改名
- **响应式布局**：自适应手机、平板、桌面设备，支持横竖屏切换
- **实时状态同步**：多页面共享矩阵输入/输出绑定状态
- **自动重连**：设备断线后自动重连，带心跳检测机制
- **持久化配置**：所有配置自动保存，重启后保持

## 技术栈

- **Flutter** ^3.12.2
- **Dart** ^3.12.2
- **通信协议**：TCP / UDP / Sony VISCA over IP
- **状态管理**：ChangeNotifier + ListenableBuilder
- **本地存储**：SharedPreferences
- **代码规范**：flutter_lints

## 项目结构

```
lib/
├── main.dart                           # 应用入口，主页面框架（底部导航 + 页面切换）
├── pages/                              # 页面目录
│   ├── big_screen_page.dart           # 大屏拼接器控制页面（分屏模式 + 输入绑定）
│   ├── camera_control_page.dart       # 摄像头控制页面（云台 + 变焦 + 预置位）
│   ├── debug_config_page.dart         # 调试配置页面（长按标题"欢迎使用中控"进入）
│   ├── power_control_page.dart        # 时序电源控制页面（开/关控制）
│   └── video_matrix_page.dart         # 视频矩阵控制页面（输入/输出通道绑定）
├── services/                           # 服务层（业务逻辑 + 网络通信）
│   ├── base_connection.dart           # 网络连接基类（TCP/UDP + 心跳 + 重连）
│   ├── big_screen_connection.dart     # 大屏拼接器连接服务
│   ├── camera_connection.dart         # 摄像头连接服务（VISCA协议实现）
│   ├── channel_name_manager.dart      # 通道名称管理（持久化存储）
│   ├── device_config.dart             # 全局配置中心（所有参数集中管理）
│   ├── device_connection.dart         # 时序电源连接服务
│   ├── matrix_connection.dart         # 视频矩阵连接服务
│   └── matrix_state.dart              # 矩阵状态共享（输入/输出绑定关系）
├── utils/                              # 工具类
│   ├── rename_dialog.dart             # 重命名对话框组件
│   └── responsive_utils.dart          # 响应式布局工具类
└── widgets/                            # 通用组件
    ├── channel_button.dart            # 通道按钮（支持长按进度条 + 改名）
    ├── channel_button_grid.dart       # 通道按钮网格（单页/多页自适应）
    ├── page_indicator.dart            # 分页圆点指示器
    ├── section_card.dart              # 分区卡片容器
    └── square_button.dart             # 方形按钮（摄像头选择 + 预置位）
```

## 快速开始

### 环境要求
- Flutter SDK ^3.12.2
- Dart SDK ^3.12.2
- Android SDK / Xcode（根据目标平台）

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
# 调试模式运行
flutter run

# 构建 Android 发布包
flutter build apk --release

# 构建 Android App Bundle
flutter build appbundle --release
```

### Windows 开发者模式
在 Windows 上构建时，需要开启开发者模式：
```powershell
# 以管理员身份运行 PowerShell
start ms-settings:developers
```

## 配置指南

### 进入配置页面
在主页面**长按顶部标题"欢迎使用中控系统"**，即可进入调试配置页面。

### 设备品牌配置
每种设备（视频矩阵、大屏拼接器、时序电源）都支持选择预设品牌：
1. 在配置页面选择设备类型
2. 点击"设备品牌"下拉框选择品牌
3. 系统**自动填充**：通信协议、端口号、指令发送模式、控制指令
4. 开发者**只需修改 IP 地址**即可

### 添加新品牌
在 `lib/services/device_config.dart` 中的品牌配置列表添加新的 `BrandConfig`：

```dart
static final List<BrandConfig> matrixBrandConfigs = [
  const BrandConfig(
    name: '新品牌',
    useTcp: true,        // true=TCP, false=UDP
    port: 8080,          // 通信端口
    sendAsHex: false,    // false=ASCII, true=16进制
    asciiCmd: 'SWITCH {input} {output}\r\n',
    hexCmd: '02 03 {input02X} {output02X} FF',
  ),
];
```

### 页面显示控制
在配置页面的"页面显示控制"区域，可以开关以下页面：
- 时序电源控制
- 大屏控制
- 视频矩阵控制
- 摄像头控制

关闭后，对应的页面及底部导航按钮将不再显示。

### 指令模板占位符
- `{input}` / `{output}` — ASCII 模式下的输入/输出通道号（十进制）
- `{input02X}` / `{output02X}` — 16进制模式下的输入/输出通道号（两位大写16进制）
- `{layout}` — 大屏分屏模式编号

## 开发者指南

### 配置中心（device_config.dart）
所有可配置参数集中在 `DeviceConfig` 类中，包括：
- **设备参数**：IP、端口、协议、指令内容
- **布局参数**：按钮尺寸、间距、字体大小
- **UI主题**：颜色、圆角、动画时长
- **交互参数**：长按时长、心跳间隔、重连间隔

### 网络连接架构
```
BaseConnection（基类）
├── TCP 连接管理
├── UDP 连接管理
├── 心跳检测
├── 自动重连
└── 状态通知

DeviceConnection（时序电源）
BigScreenConnection（大屏拼接器）
MatrixConnection（视频矩阵）
CameraConnectionManager（摄像头）
```

### 状态共享机制
- **MatrixState**：单例 ChangeNotifier，管理视频矩阵的输入/输出绑定关系
- **ChannelNameManager**：单例，管理通道自定义名称的持久化存储
- **DeviceConfig**：单例 ChangeNotifier，管理所有配置参数的持久化存储

### 添加新页面
1. 在 `lib/pages/` 创建新页面文件
2. 在 `lib/services/device_config.dart` 添加页面显示开关
3. 在 `lib/main.dart` 的 `_buildPageEntries()` 中添加页面配置

## 通信协议说明

### 视频矩阵
- **ASCII 模式**：发送文本指令，如 `MATRIX:IN1->OUT2\r\n`
- **16进制模式**：发送字节流，如 `02 03 01 02 FF`

### 大屏拼接器
- **ASCII 模式**：`LAYOUT:1\r\n`
- **16进制模式**：`03 01 01 FF`

### 时序电源
- **ASCII 模式**：`POWER_ON\r\n` / `POWER_OFF\r\n`
- **16进制模式**：`01 05 00 00 FF 00`

### 摄像头（Sony VISCA over IP）
- 数据包结构：`01 00 00 [length] 00 00 00 01 + VISCA payload`
- 地址字节：`0x80 + cameraNumber`
- 方向控制：支持 8 方向 + 停止（释放自动停止）
- 变焦控制：Tele（放大）/ Wide（缩小）
- 预置位：调用 / 保存两种模式

## 注意事项

### Android 9+ 真机网络配置
Android 9+ 真机默认禁止明文 HTTP/TCP 流量，需要在 `android/app/src/main/res/xml/network_security_config.xml` 中配置：
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true"/>
</network-security-config>
```

### 路径字符问题
项目路径包含非 ASCII 字符时，Windows 构建可能失败。需要在 `android/gradle.properties` 中添加：
```properties
android.overridePathCheck=true
```

### Gradle 缓存清理
遇到 `compressDebugAssets` 等 Gradle 构建错误时：
```bash
flutter clean
flutter pub get
```

### 摄像头连接管理
- 同一时间只连接一个摄像头
- 切换摄像头时，旧摄像头的连接和心跳会被自动清理
- 每个指令前发送缓冲区清空命令确保即时执行

## 许可证

本项目为私有项目，未经授权不得用于商业用途。

## 更新日志

### v1.0.0
- 初始版本发布
- 支持时序电源、大屏拼接器、视频矩阵、摄像头控制
- 支持 TCP/UDP 双协议
- 支持设备品牌配置
- 支持页面显示开关
- 支持通道长按重命名
- 支持响应式布局
