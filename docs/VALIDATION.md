# 验证记录

- Flutter 静态检查：通过。
- 核心回归 13 项：通过，涵盖周次／停课、连续与非连续课节、统一时间映射、JSON 往返、日程冲突、待办删除、异常 AI 批次不落盘、重启读取、并发保存、过期回复、撤销、损坏恢复及字段类型校验。
- 生产界面回归 3 项：通过，覆盖课程编辑和实际保存、待办编辑、AI 抽屉和新对话、设置、日程、浅／深色及小屏。明确检查地点文字没有省略且在卡片边界内，晚间入口位于导航之上。
- 视觉产物见 `docs/review/`；它们是 Flutter 渲染，不是真机截图。
- GitHub APK 流程固定为 Test → Build APK。安装包使用验收签名，不等同于 Play 商店发布。
- 尚需 Android 实机验证：文件选择与分享、中文识字、通知权限／省电行为、桌面小组件、真实自定义 AI 服务。没有配置用户密钥，不声称已完成真实 AI 接口验证。

## 已核验安装包

- [最终构建](https://github.com/ddyec/YIClass/actions/runs/42322500055)：Test 与 Build APK 均成功。依赖仓库一次返回 429，单独重试打包后成功，未重复执行已通过的测试。
- 应用 ID `com.ddyec.yiclass`，版本 `3.3.0 (330)`，最低 API 24，目标 API 36，`debuggable=false`。
- ARM64、ARMv7 与 x86-64 通用包；已读取 `lib/arm64-v8a/libapp.so` 的 ELF 头，确认 ELF64 / AArch64。
- `apksigner verify`、ZIP 完整性与 CI 校验和核对均通过。使用 Android Debug 验收证书，不是 Play 商店发布身份。
- SHA-256：`ec7125707cfc7b02a806ce9e1b5d335c34b2cd814fde729dd42a4f8e46a4c255`。
- [APK 下载](https://github.com/ddyec/YIClass/actions/runs/42322500055/artifacts/13553937967)。
