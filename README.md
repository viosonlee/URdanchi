# 日本UR团地地图应用

[English README](README_EN.md)

## 免责声明

**本项目仅用于学习交流目的，不用于商业用途。如有侵权，请联系删除。**


## 项目介绍

这是一个基于Flutter开发的日本UR（都市再生机构）团地查看应用。该应用提供以下功能：

### 主要功能

- **团地地图浏览**: 在交互式地图上查看日本各地的UR团地位置
- **团地详情查看**: 浏览团地的详细信息，包括房型、租金、设施等
- **多语言支持**: 支持日语、英语、中文、韩语等多种语言
- **搜索功能**: 可以按地区、房型等条件搜索团地
- **收藏功能**: 收藏感兴趣的团地，方便后续查看

### 技术特点

- 基于Flutter框架，支持Android、iOS、Web、Windows、Linux多平台
- 使用Flutter Map插件实现地图功能
- 支持国际化（i18n）
- 响应式设计，适配不同屏幕尺寸

### 数据来源

本应用使用的团地数据来源于日本UR都市再生机构的公开信息。

## 构建说明

### 环境要求

- Flutter SDK 3.8.1+
- Dart SDK 3.8.1+

### 运行步骤

1. 克隆项目
```bash
git clone https://github.com/your-repo/danchi_map_app.git
cd danchi_map_app
```

2. 安装依赖
```bash
flutter pub get
```

3. 生成本地化文件
```bash
flutter gen-l10n
```

4. 运行应用
```bash
flutter run
```

### 构建发布版本

- Android APK: `flutter build apk --release`
- iOS IPA: `flutter build ios --release`
- Web: `flutter build web --release`
- Windows: `flutter build windows --release`
- Linux: `flutter build linux --release`

## 自动化构建

本项目配置了GitHub Actions工作流，支持：

- 自动构建多平台版本
- 代码推送时自动触发构建
- 创建版本标签时自动发布

## 贡献指南

欢迎提交Issue和Pull Request来改进这个项目。

## 许可证

本项目基于 MIT 许可证开源。详情请查看 [LICENSE](LICENSE) 文件。

本项目仅供学习交流使用。

---

**注意**: 本应用显示的团地信息仅供参考，实际租赁条件请以UR官方信息为准。