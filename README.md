# Mac Health Check

Claude Code skill — 一键诊断 Mac 系统健康，并按需预览磁盘清理空间。

底层优先使用 [Mole](https://github.com/tw93/mole) (`mo status`) 拿丰富数据（健康分、电池温度、Swap 真实占比、AirPods 电量、风扇转速……），未安装 Mole 时自动降级到内置 `sysmon.sh`，仍能给出基础体检。

## 效果

聊天里随口说「电脑好慢」「风扇又在转」「磁盘是不是满了」「能省多少空间」即可触发，输出形如：

```
## 系统概览
| 指标 | 状态 |
|------|------|
| 健康分 | 85/100 — Good |
| 内存 | 24/32GB (75%) — 偏紧 |
| Swap | 6.8/8GB (84%) — 告急 ⚠️ |
| CPU  | 37% 用量, load 3.38 — 正常偏忙 |
| 磁盘 | 452/926GB (48%) — 充足 |
| 电池 | 100% 充电中 · Normal · 36 循环 · 健康 100% |
| 温度 | 30.5°C — 常温 |

## 占用大户 (Top 5)
| 进程 | CPU% | MEM% | 说明 |
| claude | 27.5% | 2% | 当前会话本身 |
| ChatGPT Atlas Service | 10.5% | 0.4% | 后台占用 |
| ...

## 异常提醒
- Swap 84% 已告急，系统在大量换页
- 已连续运行 10 天未重启

## 建议
- 关掉不用的 ChatGPT Atlas 标签
- 性价比最高的方案：重启一次
```

## 安装

### 1. 安装 Mole（强烈推荐，否则只能用降级模式）

```bash
brew install tw93/tap/mole
```

确认装好：

```bash
mo --version    # 应输出 Mole version 1.34.0 或更新
```

附带依赖：`jq`（用来解析 `mo status` 的 JSON）。多数 Mac 已自带，没有的话：

```bash
brew install jq
```

> **不装 Mole 也能用**：脚本会自动跑 `sysmon.sh` 兜底，但拿不到健康分、电池温度、AirPods 电量、Swap 占比等高级信号。强烈建议装。

### 2. 克隆为 Claude Code skill

```bash
git clone https://github.com/DoTheWorkNow/mac-health-check.git ~/.claude/skills/mac-health-check
```

新会话启动后，Claude Code 会自动加载这个 skill。

## 使用

直接用自然语言触发即可，不用记命令：

| 你说 | 触发模式 |
|------|---------|
| 「电脑好慢」「风扇响」「内存吃紧」「检查一下我的电脑」 | 默认体检 (`health.sh`) |
| 「帮我清理」「能省多少空间」「磁盘满了」「看看垃圾」 | 深度模式 (`health.sh --deep`)，附带 `mo clean --dry-run` 预览 |

也可以直接喊命令：

```bash
bash ~/.claude/skills/mac-health-check/scripts/health.sh           # 默认
bash ~/.claude/skills/mac-health-check/scripts/health.sh --deep    # 含清理预览
```

## 进阶：Mole 子命令

skill 会根据情况建议你执行 Mole 的对应 sub-command，全部安全（默认 dry-run，要你确认才动手）：

| 场景 | 命令 |
|------|------|
| 预览能清多少缓存/日志 | `mo clean --dry-run` |
| 交互式磁盘占用浏览 | `mo analyze` |
| 找老 node_modules / build 产物 | `mo purge --dry-run` |
| 彻底卸载某 App（连配置缓存） | `mo uninstall <app>` |
| 系统维护类优化 | `mo optimize --dry-run` |

## 文件结构

```
mac-health-check/
├── SKILL.md              # Skill 定义（触发条件、输出格式、判断标准、决策树）
├── scripts/
│   ├── health.sh         # 主入口：优先 Mole，缺席时降级 sysmon
│   └── sysmon.sh         # 兜底采集脚本（无依赖纯 shell）
└── README.md
```

## 设计思路

- **一次 Bash 调用**：脚本在 shell 层用 `jq` 把 `mo status` 的 ~10KB JSON 收敛成 ~30 行紧凑文本，Claude 一次调用拿到全部数据
- **省 token**：避免让 Claude 再跑 `top` / `ps` / `vm_stat`，输出直接是表格友好的结构化文本
- **降级兜底**：没有 Mole 也能跑出基础报告，迁移新机器不掉链子
- **只读安全**：体检脚本只读系统状态；`--deep` 也只跑 `mo clean --dry-run`，绝不主动删文件，所有清理动作都由用户拍板执行

## License

MIT
