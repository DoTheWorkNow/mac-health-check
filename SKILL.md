---
name: mac-health-check
description: 快速诊断 Mac 系统健康状况并给出可执行建议。覆盖内存、CPU、磁盘、电池、温度、Swap、AirPods 电量、占用大户进程，必要时还能预览磁盘清理空间。当用户提到电脑慢、卡顿、风扇响、发热、内存吃紧、磁盘满、空间不足、清理缓存、系统监控、Mac 状态、check system health、memory usage、disk full、Mac running slow 时触发。即使用户只是随口说「电脑好慢」「风扇又在转」「磁盘是不是满了」也应该触发；用户说「帮我清理一下」「能省多少空间」「看看垃圾」则启用 --deep 模式。
---

# Mac Health Check

一键诊断 Mac 系统健康并按需预览清理空间。优先使用 [Mole](https://github.com/tw93/mole) 拿丰富数据（健康分、温度、AirPods 电量、Swap 真实占比等），缺席时自动回退到内置 `sysmon.sh`。

## 工作流程

### 默认：状态体检

```bash
bash ~/.claude/skills/mac-health-check/scripts/health.sh
```

### 用户表达了清理意图时：附带清理预览

触发词：「清理」「空间不够」「磁盘满了」「能省多少」「垃圾」「太占地」。

```bash
bash ~/.claude/skills/mac-health-check/scripts/health.sh --deep
```

`--deep` 会在体检后追加 `mo clean --dry-run` 的摘要（仅 dry-run，不删除）。

## 输出格式

只用一份紧凑表格 + 重点建议，不要复述脚本原文：

```
## 系统概览
| 指标 | 状态 |
|------|------|
| 健康分 | XX/100 — [Excellent/Good/Fair/Poor] |
| 内存 | XX/XXGB (XX%) — [正常/偏高/紧张] |
| Swap | XX/XXGB (XX%) — [充裕/吃紧/告急] |
| CPU  | XX% 用量, load XX — [空闲/正常/繁忙] |
| 磁盘 | XX/XXGB (XX%) — [充足/偏紧/告急] |
| 电池 | XX% [充电/放电] · 健康 [Normal/...] · XX 循环 |
| 温度 | XX°C [常温/温热/烫] |

## 占用大户 (Top 5)
| 进程 | CPU% | MEM% | 说明 |

## 异常提醒
- AirPods 右耳 11% 等
- iOS 模拟器卷 97% 等

## 建议
- 可执行的具体动作（关 App / kill 残留进程 / 重启 / mo clean）
```

## 判断标准

| 维度 | 正常 | 偏紧 | 告急 |
|------|------|------|------|
| 内存压力 | <60% | 60–80% | >80% |
| Swap 占比 | <50% | 50–80% | >80% |
| CPU idle | >40% | 20–40% | <20% |
| 磁盘 | <70% | 70–85% | >85% |
| 单进程 RSS | <500MB | 500MB–1GB | >1GB |
| 单进程 CPU | <50% | 50–100% | >100%（满核） |
| 电池温度 | <35°C | 35–40°C | >40°C |

**Swap 比内存压力更先反映瓶颈**——内存看起来 64% 但 Swap 已 80%，说明系统已经在拼命换页，体感会卡。

## 升级行动建议（决策树）

根据情况建议执行 Mole 的对应 sub-command：

| 触发条件 | 建议命令 | 用途 |
|----------|---------|------|
| 用户说想清理 / 磁盘 >75% / Swap >80% | `mo clean --dry-run` | 缓存日志清理预览 |
| 磁盘 >85% 且想知道空间去哪了 | `mo analyze` | 交互式磁盘占用浏览 |
| 用户是开发者且抱怨空间 | `mo purge --dry-run` | 找老 node_modules / build 产物 |
| 系统跑了 >7 天没重启 + Swap 紧 | 建议重启 | 最便宜的清理手段 |
| 用户想完全卸载某 App | `mo uninstall <app>` | 连带配置和缓存清掉 |
| 系统维护类（休眠、SMC） | `mo optimize --dry-run` | 系统优化预览 |

**决策原则**：能用一条命令解决就别拆开；先 dry-run 让用户拍板再执行；永远不要直接 `mo clean` / `mo uninstall`，必须用户确认。

## 建议原则

- 给具体的可执行动作，不空谈"试试清理一下"
- 区分"短期可立即做"（关 App、kill 进程）与"系统级建议"（重启、`mo clean`）
- Electron 应用多开（VSCode、Chrome、ChatGPT、Claude desktop）是常见内存大户
- 跑了很久没重启 + Swap 高换页时，重启永远是性价比最高的建议
- AirPods 单耳低电量也要提醒（用户经常忽略）
- iOS 模拟器卷 97% 是正常现象（DMG 镜像满载），别误报为告急

## Token 节省策略

- `health.sh` 已在 shell 层用 `jq` 把 `mo status` 的 ~10KB JSON 收敛成 ~30 行紧凑文本，不要再单独跑 `mo status`、`top`、`vm_stat`、`ps` 等命令
- 默认模式不要带 `--deep`，那会触发文件系统全扫描（耗时）
- Mole 缺席时脚本自动回退到 `sysmon.sh`，无需手动判断
