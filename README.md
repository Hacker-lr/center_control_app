# 中控系统 App (Center Control App)

一个基于 Flutter 开发的跨平台中控系统应用，用于集中控制会议室/展厅中的多种硬件设备，包括时序电源、大屏拼接器、视频矩阵、摄像头，以及大屏电箱 PLC（LED 电源）。支持 **TCP/UDP 直连** 与 **Crestron VTP 中控联动** 两种工作模式，配套设备品牌配置、区块可选显隐、响应式布局和实时状态同步。

## 功能特性

### 设备控制
- **时序电源控制**：远程开关电源设备，支持 TCP/UDP 协议切换
- **大屏电箱 PLC 控制（LED 电源）**：控制大屏电箱内的 PLC（参考 `LED_Leyard_PWR.usp`，Modbus ASCII over RS485 经网转串透传），提供「大屏开 / 大屏关」
- **大屏拼接器控制**：切换分屏模式（全屏、二分屏、三分屏、四分屏、五分屏、全屏 16:9），支持可视化预览
- **视频矩阵控制**：输入/输出通道绑定切换，支持长按通道按钮重命名
- **摄像头控制**：基于 Sony VISCA over IP 协议，支持云台方向控制、变焦、预置位调用/保存

### 双工作模式（核心特性）
- **直连模式（默认）**：App 直接通过 TCP/UDP 向各设备发送指令
- **Crestron VTP 联动模式**：开启 `crestronMode` 后，所有控制页按钮不再直连，而是向 Crestron 处理器发送对应的 **Join**（数字 / 模拟 / 串口信号），由中控程序统一调度。每个动作对应的 Join 号可在配置页集中配置（见「VTP Join 映射」）

### 系统功能
- **电源控制页双区块可选显隐**：「时序电源控制」「大屏电源控制」两个区块可独立勾选显示（勾哪个显示哪个）；两个区块同时显示时整体自动缩小，只显示一个时保持原尺寸
- **TCP/UDP 双协议支持**：每种设备独立选择通信协议
- **设备品牌配置**：预置多种设备品牌，选择后自动填充协议、端口和控制指令
- **页面显示开关**：通过配置页面控制各功能页面的显示/隐藏
- **长按重命名**：视频矩阵输入/输出通道、摄像头选择按钮、预置位按钮均支持长按改名
- **响应式布局**：自适应手机、平板、桌面设备，支持横竖屏切换
- **实时状态同步**：多页面共享矩阵输入/输出绑定状态；CIP 连接状态实时反馈
- **自动重连**：设备断线后自动重连，带心跳检测机制
- **持久化配置**：所有配置自动保存，重启后保持
- **流畅动画**：VTP 菜单开合镜像动画、配置页跳转上浮缩放、各状态切换过渡

## 技术栈

- **Flutter** ^3.12.2
- **Dart** ^3.12.2
- **通信协议**：
  - TCP / UDP 直连（ASCII / 16 进制）
  - Sony VISCA over IP（摄像头）
  - Modbus ASCII over RS485（大屏电箱 PLC，经网转串网关）
  - Crestron CIP / SCIP（中控联动，含 TLS 安全模式）
- **状态管理**：ChangeNotifier + ListenableBuilder
- **本地存储**：SharedPreferences
- **依赖**：`crypto`（SCIP 安全认证哈希）
- **代码规范**：flutter_lints

## 项目结构

```
lib/
├── main.dart                           # 应用入口，主页面框架（底部导航 + 按需连接 + 配置页跳转动画）
├── pages/                              # 页面目录
│   ├── big_screen_page.dart           # 大屏拼接器控制页面（分屏模式 + 输入绑定）
│   ├── camera_control_page.dart       # 摄像头控制页面（云台 + 变焦 + 预置位）
│   ├── crestron_page.dart             # Crestron 中控页面（CIP 连接状态 / 事件日志 / 认证日志）
│   ├── system_config_page.dart        # 系统配置页面（长按标题"欢迎使用中控系统"进入）
│   ├── power_control_page.dart        # 电源控制页面（时序电源 + 大屏电箱 PLC 双区块）
│   └── video_matrix_page.dart         # 视频矩阵控制页面（输入/输出通道绑定）
├── services/                           # 服务层（业务逻辑 + 网络通信）
│   ├── base_connection.dart           # 网络连接基类（TCP/UDP + 心跳 + 重连 + 写队列）
│   ├── camera_connection.dart         # 摄像头连接服务（VISCA协议实现，CameraConnectionManager）
│   ├── channel_name_manager.dart      # 通道名称管理（持久化存储）
│   ├── crestron_cip_connection.dart   # Crestron CIP/SCIP 连接服务（单例，Join 状态机 + 订阅）
│   ├── device_config.dart             # 全局配置中心（所有参数集中管理，含 Crestron Join 映射）
│   ├── device_connection.dart         # 通用设备连接服务（按 DeviceProfile 区分：时序电源 / 大屏拼接器 / 大屏电箱 PLC）
│   ├── video_matrix_connection.dart   # 视频矩阵连接服务
│   └── video_matrix_state.dart        # 矩阵状态共享（输入/输出绑定关系）
├── utils/                              # 工具类
│   ├── channel_rename_dialog.dart     # 通道重命名对话框组件
│   └── responsive_utils.dart          # 响应式布局工具类
└── widgets/                            # 通用组件
    ├── channel_button.dart            # 通道按钮（支持长按进度条 + 改名）
    ├── channel_button_grid.dart       # 通道按钮网格（单页/多页自适应）
    ├── config_form_widgets.dart       # 配置页共享表单构件（IP/端口、品牌下拉、协议开关、勾选开关等）
    ├── crestron_status_chip.dart      # Crestron 全局连接状态芯片
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
在主页面**长按顶部标题"欢迎使用中控系统"**，即可进入系统配置页面。所有分组默认收起，点击标题可展开/折叠。

### 设备品牌配置
每种设备（视频矩阵、大屏拼接器、时序电源、大屏电箱 PLC）都支持选择预设品牌：
1. 在配置页面展开对应设备分组
2. 点击"设备品牌"下拉框选择品牌
3. 系统**自动填充**：通信协议、端口号、指令发送模式、控制指令
4. 开发者**只需修改 IP 地址**即可

> LED 电源（大屏电箱 PLC）默认品牌为「利亚德」，指令为固定 Modbus ASCII 帧，发送模式固定为 ASCII。

### 电源设备配置（时序电源 + 大屏电箱 PLC 合并菜单）
配置页中将「时序电源」与「大屏电箱 PLC」整合为**同一个「电源设备」菜单栏**，内部依次包含：
- 时序电源设备（IP / 端口 / 品牌 / 协议）—— 直连字段在 VTP 模式下按反向动画淡出收起
- ☑ 时序电源控制区块（勾选显示）
- 大屏电箱 PLC（IP / 端口 / 品牌 / 协议）—— 同上
- ☑ 大屏电源控制区块（PLC）（勾选显示）

两个区块勾选开关**始终可见**（即便在 VTP 模式下也能切换），控制电源控制页内对应区块的显隐；两者相互独立，可单独或同时显示。

### Crestron VTP 双模式配置
1. 在配置页展开「Crestron 中控」分组，打开 **Crestron VTP 模式** 总开关
2. 填写中控主机 IP、端口（明文 41794 / 安全 41796）、IP-ID（十六进制，如 0x0A）
3. 如需 4 系列 TLS 安全连接：打开「安全 CIP」，并填写认证用户名 / 密码
4. 展开「VTP Join 映射」分组，按需修改每个动作对应的 Join 号（默认映射见下方"通信协议"）
5. 开启后，四个控制页按钮自动改为向中控发送对应 Join；关闭则恢复直连

### 页面显示控制
在配置页面的"页面显示控制"区域，可以开关以下页面：
- 时序电源控制
- 大屏控制
- 视频矩阵控制
- 摄像头控制
- Crestron 中控

关闭后，对应的页面及底部导航按钮将不再显示。

### 指令模板占位符
- `{input}` / `{output}` — ASCII 模式下的输入/输出通道号（十进制）
- `{input02X}` / `{output02X}` — 16 进制模式下的输入/输出通道号（两位大写 16 进制）
- `{layout}` / `{layout02X}` — 大屏分屏模式编号（十进制 / 两位 16 进制）

## 开发者指南

### 配置中心（device_config.dart）
所有可配置参数集中在 `DeviceConfig` 单例类中，包括：
- **设备参数**：IP、端口、协议、指令内容
- **Crestron 双模式**：总开关、主机参数、各动作 Join 映射
- **布局参数**：按钮尺寸、间距、字体大小
- **UI 主题**：颜色、圆角、动画时长
- **交互参数**：长按时长、心跳间隔、重连间隔

> **默认值单一数据源**：所有"默认值"（默认 IP / 端口 / Join 号 / 指令 / 开关 / 网格参数等）统一放在同文件的 `ConfigDefaults` 类中。字段初始化、`_loadAllConfig` 加载、`resetAll` 重置三处均引用它，**修改默认配置只需改 `ConfigDefaults` 一处**，避免同一数值在多处重复出现而漂移。品牌相关默认值仍由各 `*BrandConfigs` 列表管理。

修改配置后自动保存到 SharedPreferences，启动自动加载，调用 `resetAll()` 恢复默认。

### 网络连接架构
```
BaseConnection（基类：TCP/UDP + 心跳 + 重连 + 串行写队列）
├── DeviceConnection（通用配置驱动设备连接，按 DeviceProfile 区分实例）
│   ├── DeviceProfile.timingPower（时序电源）
│   ├── DeviceProfile.bigScreen（大屏拼接器）
│   └── DeviceProfile.ledPower（大屏电箱 PLC）
├── VideoMatrixConnection（视频矩阵）
├── CameraConnectionManager（摄像头，VISCA）
└── CrestronCipConnection（Crestron CIP/SCIP，Join 状态机 + 订阅回调）
```
所有连接类共享基类的心跳、看门狗、重连与字节→十六进制格式化逻辑；TCP 写操作统一进入串行队列，保证心跳/指令/CIP 帧不会交错。

### 状态共享机制
- **VideoMatrixState**：单例 ChangeNotifier，管理视频矩阵的输入/输出绑定关系
- **ChannelNameManager**：单例，管理通道自定义名称的持久化存储
- **DeviceConfig**：单例 ChangeNotifier，管理所有配置参数的持久化存储
- **CrestronCipConnection**：单例，管理 Crestron Join 状态与订阅

### 添加新页面
1. 在 `lib/pages/` 创建新页面文件
2. 在 `lib/services/device_config.dart` 添加页面显示开关
3. 在 `lib/main.dart` 的 `_buildPageEntries()` 中添加页面配置（含按需连接/断开回调）

### 添加新品牌
在 `lib/services/device_config.dart` 对应品牌配置列表中添加新的 `BrandConfig`（见文件内「开发者提示」注释）。

## 通信协议说明

### 视频矩阵
- **ASCII 模式**：发送文本指令，如 `MATRIX:IN1->OUT2\r\n`
- **16 进制模式**：发送字节流，如 `02 03 01 02 FF`

### 大屏拼接器
- **ASCII 模式**：`LAYOUT:1\r\n`
- **16 进制模式**：`03 01 01 FF`

### 时序电源
- **ASCII 模式**：`POWER_ON\r\n` / `POWER_OFF\r\n`
- **16 进制模式**：`01 05 00 00 FF 00` / `01 05 00 00 00 00`

### 大屏电箱 PLC（LED 电源，Modbus ASCII）
- 参考 `LED_Leyard_PWR.usp`：Modbus ASCII over RS485，经网转串 TCP 网关透传
- 命令格式 `:AA FC RR RR NN NN DD DD CC\r\n`（AA=从站 00，FC=10 写多寄存器，RRRR=起始寄存器 00B0，NNNN=寄存器数 0001，DDDD=数据，CC=LRC）
- 开：`:001000B0000100013E\r\n`（数据 0001）
- 关：`:001000B0000100023D\r\n`（数据 0002）

### 摄像头（Sony VISCA over IP）
- 数据包结构：`01 00 00 [length] 00 00 00 01 + VISCA payload`
- 地址字节：`0x80 + cameraNumber`
- 方向控制：支持 8 方向 + 停止（释放自动停止）
- 变焦控制：Tele（放大）/ Wide（缩小）
- 预置位：调用 / 保存两种模式

### Crestron CIP / SCIP
- 3 系列 / 未加密 CIP：明文 TCP，端口 41794
- 4 系列 / 安全 CIP（SCIP）：TLS 加密 TCP，端口 41796，需认证
- 帧格式 `[type:1][length:2 大端][payload:length]`；握手顺序：注册请求 0x0F → 注册包 0x01（含 IP-ID）→ 成功 0x02 → update request 0x05 → end-of-query 0x1C → 心跳 0x0D
- App 侧提供 Join 状态机与 `subscribe` 订阅回调，按钮发 `pulse`（脉冲）/ `press`+`release`（按住）

#### Crestron Join 默认映射（crestronMode 开启时生效）
| 功能 | Join |
| --- | --- |
| 电源开 / 关 | 21 / 22 |
| 大屏电源(PLC) 开 / 关 | 23 / 24 |
| 分屏（全屏） | 552 |
| 分屏（全屏 16:9） | 553 |
| 分屏（二分 / 三分 / 四分 / 五分） | 554 / 555 / 556 / 557 |
| 矩阵 输入 X / 输出 Y | 基址 50 + X / 基址 130 + Y |
| 摄像机选择 X | 基址 510 + X |
| 摄像机 上/下/左/右 | 524 / 525 / 526 / 527 |
| 摄像机 推近 / 拉远 | 528 / 529 |
| 摄像机 低速 / 高速 | 521 / 522 |
| 摄像机 保存按钮 | 523 |
| 摄像机 预置位 N（调出/保存） | 基址 530 + N |

> 基址类 Join 均为「基址 + 偏移」形式；分屏六个按钮各有独立 Join（非基址）。

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

### Crestron 安全认证（4 系列）
- 4 系列处理器若开启"身份验证"，在 TLS 之上还需一次挑战-应答认证
- 认证哈希算法需以真实抓包为准；当前 `crestron_cip_connection.dart` 中的 `_computeAuthResponse` / `_sendAuthResponse` 为社区常见实现占位，连接前会在 `_authLog` 记录挑战数据供联调，**切勿在生产环境依赖其正确性**

## 许可证

本项目为私有项目，未经授权不得用于商业用途。

## 更新日志

### v1.1.0
- **新增 Crestron VTP 双模式**：开启后四个控制页按钮改为向中控发送对应 Join（数字/模拟/串口），支持 3 系列明文 CIP 与 4 系列 TLS 安全 CIP
- **新增 Crestron 中控页面**：展示 CIP 连接状态、握手事件日志与安全认证调试日志
- **新增大屏电箱 PLC（LED 电源）设备**：参考 `LED_Leyard_PWR.usp`（Modbus ASCII），提供「大屏开 / 大屏关」按钮
- **电源控制页双区块可选**：时序电源与大屏电源两个区块可独立勾选显示；同时显示时整体自动缩小，只显示一个时保持原尺寸
- **配置页整合**：时序电源与大屏电箱 PLC 合并为单一「电源设备」菜单栏，勾选显示开关内置其中
- **动画优化**：VTP 菜单开合镜像动画（先下移后淡入）、配置页跳转上浮 + 缩放 + 渐显过渡
- 默认 IP/端口占位值统一为 `192.168.0.64`

### v1.0.0
- 初始版本发布
- 支持时序电源、大屏拼接器、视频矩阵、摄像头控制
- 支持 TCP/UDP 双协议
- 支持设备品牌配置
- 支持页面显示开关
- 支持通道长按重命名
- 支持响应式布局
