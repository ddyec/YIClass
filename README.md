# YIClass Android

全新 Flutter Android 版，以原生 iOS 3.3.0 的设计和工作流程为基准。不读取旧 Isar 数据库。以统一的 Material 3 Expressive 主题适配 Android：鲜明的文字层级、色彩角色、成组圆角表单、贴边 Material 导航和独立 AI 操作，不混用 Cupertino 控件。保留书页产品标识与浅深色线稿助手。

- 周／日／列表、多课表、课程增删改、周次与单双周、未排时间课程、停课日期、冲突并排。
- 统一 4+4+2 课节时间；编辑开始／结束联动后续课节；统一时长和课间保留午休；增减课节映射所有课表，禁止删除正在使用的节次。
- 待办重要程度、截止时间、完成／重开、紧迫度配色与文字、折叠已完成。工作时间独立于截止时间，日时间轴混排课程与待办并将冲突分列。
- AI 对话抽屉、新对话、独立历史、取消、一次撤销；明确修改直接校验并保存，失败整批不落盘，资料更新后拒绝过期回复。支持以实际下一次开课时间设置待办截止。
- 自定义 HTTPS OpenAI 兼容接口，DeepSeek 快捷填写，用未保存配置测试。密钥放 Android 安全存储，拒绝重定向和截断输出。
- JSON 课表导入／导出兼容 iOS；完整备份单独包含待办、日程、历史，不含密钥。导入新建课表并预览，默认保留统一时间。
- 图片与 PDF 使用捆绑的 ML Kit 中文模型本机识字，保留页码与文字坐标；TXT／CSV 可读取、编辑后交给所配置 AI 整理成课表。识别有误可以返回文字编辑再生成预览。PDF 最多 20 页，文件最多 20 MB，读取或识别可取消，迟到结果不应用。
- Android 原生课程／待办桌面小组件，以及课程、已安排待办的系统通知。修改、切换、撤销、回到前台均刷新，重启后恢复已保存的提醒计划。

## 信息密度与课程可读性

顶部课表操作和视图切换合为两行；底栏使用标准 Material 导航，不预留悬浮玻璃胶囊的额外空白。日视图按时间顺序显示紧凑日程，实际重叠事件分列，不绘制整屏空置的 24 小时。

周课表使用实际字体测量课程文字。常见课名尽量显示全；极长课名保留最多四行可辨认前缀，点击或长按可读全文。地点单独计算所需高度，避免与长课名同时被省略号替代。内容多时只扩展需要的行，窄屏或冲突时可横向浏览，竖向滚动保持星期表头固定。收起状态的晚间入口始终在底部可见；展开后收起入口随内容滚动。

## 当前验收包

[下载 Android 3.3.0 APK](https://github.com/ddyec/YIClass/actions/runs/42322500055/artifacts/13553937967) · [构建与测试记录](https://github.com/ddyec/YIClass/actions/runs/42322500055) · [界面预览](docs/DESIGN.md)

包内包含 `arm64-v8a`、`armeabi-v7a` 和 `x86_64`，已核对 ARM64 的 AArch64 二进制、签名与 SHA-256。最低 Android 7.0（API 24），目标 API 36。真机安装与系统权限仍待设备验收。

## 构建与验证

Flutter 3.47.9、Java 21、Android SDK。当前验收包最低 Android 7.0（API 24）。运行：

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release
```

Actions 按 Test → Build APK 顺序执行。APK 是用构建环境调试密钥签名的可安装验收包，正式分发应配置稳定的发布密钥。应用 ID 为 `com.ddyec.yiclass`，与旧版独立安装。

`test/core_test.dart` 验证课表计算、导入、时间映射、日程和原子存储；`test/ui_test.dart` 使用生产组件执行页面操作和浅／深色小屏渲染，截图保存到 `/tmp/yiclass-review`，不属于 Android 真机截图。

## 平台对应与验收边界

Apple Intelligence、灵动岛与 WidgetKit 是 iOS 专属能力；Android 使用自定义 AI 接口、系统通知和 AppWidget。锁屏是否能放小组件由系统／启动器决定。通知默认提前 10 分钟；没有精确闹钟权限时使用系统非精确提醒，省电／强行停止应用会影响投递。当前保存未来 8 天日程，每次打开重新补充；长时间不打开不会无限延展计划。需要在真实 Android 设备验收权限、OCR、分享、小组件和通知。

PDF 目前通过页面渲染识字后由 AI 整理，不具备 iOS PDFKit 的结构化 PDF 离线解析器；Apple 设备模型也没有移植为 Android 本地大模型。不包含旧教务网页脚本仓库。以上不宣称与 iOS 所有系统能力完全等价。

原项目 Apache-2.0，保留 Copyright 2025 wykwey。设计与图标取自 `ddyec/YIClass-iOS` 3.3.0。Noto Sans SC 字体遵循 SIL Open Font License（`assets/fonts/OFL.txt`）。
