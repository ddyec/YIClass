# Android 设计与验收

统一采用 Material 3 组件，按 Material Expressive 的色彩、字体层级和形状原则适配。它不是 Google 原版应用或原生 Compose Expressive 组件的逐像素复制。

- 使用中性纸面背景与明确的主色。主要操作使用实心色，次要控件和分组降低强调，避免全页面相同的粗字、圆角和彩色块。
- 课表顶部两行操作；贴边的三目的地 Material 导航，AI 是独立操作。主程序不再使用 Cupertino 控件或仿玻璃悬浮栏。
- 课程按实际字体测量。普通课名尽量显示全，特别长的课名保留最多四行可辨认前缀，点击或长按查看全文。地点独立分配高度，不因课名长而变成省略号。
- 周视图保持星期表头固定。按内容增加需要的课节行高；屏幕或冲突列过窄时支持横向浏览。未展开时，晚间入口保持可见。
- 待办、设置、课程／待办表单、日期选择、对话抽屉和导入预览共享主题。日视图紧凑显示实际安排和冲突，不强制空置的全天网格。

参考：[Google Design 的 Expressive 研究](https://design.google/library/expressive-material-design-google-research)、[Google 的设计发布说明](https://blog.google/products-and-platforms/platforms/android/material-3-expressive-android-wearos-launch/)、[Flutter Material 文档](https://docs.flutter.dev/ui/design/material)。

`review/` 中的图片来自生产 Flutter 组件的测试渲染，使用同一批密集课程数据。它们不含 Android 状态栏，也不是 Android 真机截图。
