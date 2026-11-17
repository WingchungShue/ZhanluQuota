# 湛卢额度 · iOS 版

把 PC 端方案C（保存 key + 查询湛卢额度）搬到 iPhone。SwiftUI 原生、零第三方依赖，未签名 IPA，配合 LiveContainer 侧载。

## 功能

- 多 key 管理：添加 / 编辑 / 删除 / 剪贴板粘贴，名称+掩码显示
- 查询：左滑单查、顶部「全部查询」批量、下拉刷新、保存前试查询
- 模型列表：选任意 key 拉取 `/v1/models` 模型目录（字母序）
- 显示：剩余 / 总额 / 已用 / 剩余百分比 + 最后更新时间
- App 图标 = PC ZhanluTools 同款；桌面名称 ZhanluQuota
- 数据：JSON 存本机 Documents/zhanlu_keys.json，与 PC 端同结构

网关只走移动云（公网，iOS 查不了内网 HTTP）：
- 额度：`https://ecloud.10086.cn/api/query/aigateway/gateway/api/v1/external-ide/budget-info`
- 模型：`https://ecloud.10086.cn/api/query/aigateway/v1/models`

## 云编译出 IPA（零成本）

1. 把本目录整个传到一个 **GitHub 公开仓库**（私有也行，每月约 200 分钟 macOS 免费额度）
2. GitHub 网页 → Actions → `build-ipa` → Run workflow
3. 等约 5~10 分钟，到该次运行页底部下载 `ZhanluQuota-ipa` artifact（zip 里就是 IPA）
4. 传到手机（微信文件传输/邮件/iCloud 都行），用 **LiveContainer** 打开安装即可

流水线做三件事：XcodeGen 生成工程 → xcodebuild 未签名 archive → 打成 IPA。无需 Mac、无需 Apple 开发者账号。

## 注意

- 内网模式是 HTTP，已在 Info.plist 放开 ATS（`NSAllowsArbitraryLoads`），自用侧载无影响
- 内网模式需在能访问公司内网的网络下查询；移动云模式公网即可
- key 只存在本机，不上传任何第三方
