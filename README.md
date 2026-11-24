# 账户盾 · Apple ID Guard

防止 iPhone / Apple ID 账户被盗刷的 **原生 iOS 后台监控应用**。

## 它能做什么

1. **Mail 一键导入** — 在 Mail 中打开 Apple 收据 → 分享 → 账户盾（Share Extension）
2. **解析 Apple 收据** — 支持纯文本与 HTML 邮件正文，自动提取商户与金额
3. **AI 风险评估** — 结合消费基线、时段、频次、NaturalLanguage 语义分析，给出 0–100 风险分
4. **后台巡检** — `BGAppRefreshTask` + `BGProcessingTask` 定期扫描待处理告警
5. **即时推送** — 高危购买本地通知，一键标记「是我本人 / 不是我」
6. **越用越准** — 确认合法购买后更新个人消费基线

## 快速开始

```bash
cd active/apple-id-guard
swift test          # 核心引擎单元测试
npm test            # 工程 smoke

xcodegen generate
open AppleIDGuard.xcodeproj
```

在 iPhone 上：

1. 安装主 App 与 Share Extension（Xcode Run 到真机）
2. 允许通知与后台 App 刷新
3. **主路径**：Mail 打开 Apple 收据 → 分享 → 选择「账户盾」
4. **备用**：「导入」页粘贴邮件正文
5. 在「告警」页处理可疑订单

## Mail 工作流（推荐）

```
Mail 收据邮件 → 分享按钮 → 账户盾
        ↓
Share Extension 解析 + 风险评估
        ↓
App Group 写入 → 本地通知（中/高危）
        ↓
打开主 App 查看「最近购买 / 告警」
```

## 技术栈

- Swift 5.9 · SwiftUI · iOS 17+
- Share Extension · App Groups · BackgroundTasks · UserNotifications · NaturalLanguage
- SwiftPM 库 + xcodegen 生成 `.xcodeproj`

## 隐私

所有购买记录与基线数据保存在本机 App Group（`group.com.skat.appleidguard`），不上传云端。
