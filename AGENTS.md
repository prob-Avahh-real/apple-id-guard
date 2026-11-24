# 账户盾 (apple-id-guard)

AI 驱动的 Apple ID 购买监控：解析收据邮件、评估盗刷风险、后台巡检并推送告警。

## 用途与 Target 判定

iPhone 账户防盗刷工具 — 监控 Apple 购买、AI 异常检测、后台刷新 + 本地推送 + Mail Share Extension。

| 平台 | 需要? | 方式 |
|------|-------|------|
| 移动端 | 需要 | 原生 SwiftUI / iOS 17+ + Share Extension |
| 智能硬件 | 可选 | Apple Watch 告警（可搁置） |

## 命令

```bash
cd active/apple-id-guard
swift test
npm test
xcodegen generate && open AppleIDGuard.xcodeproj
```

## 架构

```
Mail 分享 → ShareExtension → ReceiptIngestService
手动导入 ────────────────────────┘
                ↓
         ReceiptParser → RiskEngine
                ↓
    PurchaseStore（App Group）← BaselineLearner
                ↓
    BackgroundScheduler + NotificationService
```

## App Group

- ID: `group.com.skat.appleidguard`
- 主 App 与 Share Extension 共享购买记录 / 基线 / 设置
- 首次启动自动从 `UserDefaults.standard` 迁移

## Harness / Loop（助手）

- Guide = 本文件；Sensor = `swift test` + `npm test`
- 同类失误第二次 → 补规则或测试（棘轮）

## 验证环 / Done

```bash
swift test && npm test
xcodegen generate
```

**Done**：单元测试通过；Xcode 含 `AppleIDGuard` + `AppleIDGuardShare`；真机验收：

1. Mail 打开 Apple 收据 → 分享 → 账户盾
2. 2 秒内完成，主 App 可见新记录
3. 高危购买触发本地通知
4. 杀进程重启后数据仍在

## 限制说明

iOS 不允许第三方直接拦截 App Store 支付。本应用通过 **Mail 分享 / 收据粘贴 / 手动录入** 获取购买事件。

## 助手约束

- 遵循根 `/Users/skat/AGENTS.md` Harness + Loop
- App Group entitlement 主 App 与 Extension 必须一致
