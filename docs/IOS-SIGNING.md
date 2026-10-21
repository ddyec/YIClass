# iOS 安装与主屏幕小组件

默认主应用：`com.ddyec.yiclass`  
小组件扩展：`com.ddyec.yiclass.ScheduleWidget`  
共享 App Group：`group.com.ddyec.yiclass`

Actions 输出 `YIClass-unsigned.ipa`，其中包含 `Payload/Runner.app/PlugIns/ScheduleWidget.appex`。
这是未签名包，需要自行签名后安装。最低 iOS 15。

## 签名的必要条件

1. 为主应用和扩展分别使用匹配的 provisioning profile。
2. 两个 profile 都启用同一个 App Group，保留 `com.apple.security.application-groups` entitlement。
3. 签名工具必须保留并签署嵌入的 `.appex`，不能删除扩展。
4. 如需更换 Bundle ID，请在 Actions 手动构建中填写 `bundle_id` 和可选 `app_group`。
   单独改主应用 ID 或仅重签主应用不能保证小组件工作。
5. 如签名工具更换 App Group，应用和扩展会尝试读取各自已安装描述文件中的可用共享组；两者仍必须授权同一组。

App Groups 需要开发者账号及签名方式提供相应能力；普通免费侧载或会移除扩展/共享权限的签名服务不能保证此功能。
不能只凭 IPA 构建成功宣称已通过 iPhone 小组件安装验收。

## 安装后验收

1. 打开应用一次，导入课表，确认第 1 周周一、课程周次及作息。
2. 设置 → 桌面小组件，应显示“共享课表已同步”。否则根据错误检查 App Group 签名。
3. 主屏幕长按空白处 → 编辑 → 添加小组件 → YIClass，添加小号或中号。
4. 确认课程名称、时间和地点。小组件保存整学期日程，按课程开始、结束及午夜生成时间线，不要求每天打开应用。
5. 调整某一课次后检查小组件更新；跨日、单双周及休假日亦应正确。系统控制实际刷新时机。
6. 小组件显示正在进行或最近一节未结束的课程；中号附带后续安排。点按可打开应用。

## 从源码构建

在 macOS 安装 Flutter 3.38.5、Xcode 与 CocoaPods：

```sh
flutter pub get
BUNDLE_ID=com.ddyec.yiclass APP_GROUP=group.com.ddyec.yiclass ruby scripts/configure_ios.rb
flutter build ios --release --no-codesign --build-name 2.4.1 --build-number 1
python3 scripts/verify_ios_bundle.py build/ios/iphoneos/Runner.app
```

`configure_ios.rb` 将原生 WidgetKit target、嵌入阶段、依赖及共享权限写入 Xcode 项目，可重复执行。
打开项目进行手动签名之前也要执行此步骤。
