---
name: mac-health-check
description: 诊断 Mac 卡顿、风扇响、发热、内存和 Swap 增长、磁盘空间骤降、后台进程或 iOS 模拟器占用；结合 Mole 与原生采样给出有证据的建议。用户要求清理时先预览，不自动删除、结束进程或修改系统设置。
---

# Mac Health Check

先定位瓶颈，再提出作用对象明确的动作。默认采集一次状态；空间骤降不直接等同于缓存垃圾。Mole 健康分仅为辅助信号，不能抵消用户症状或缺失数据。

## 入口与边界

从本次实际加载的 `SKILL.md` 所在目录定位脚本，不假定 `~/.claude`、`~/.codex` 或大小写别名。以下命令以该目录为工作目录：

```bash
bash scripts/health.sh          # Mole JSON 快照，失败/缺依赖时原生回退
bash scripts/health.sh --deep   # 仅在用户要求清理预览时，追加 mo clean --dry-run
```

首次使用或怀疑版本不符时读 `mo --version` 与 `mo status --help`。本版以 2026-09-20 核验的 [Mole V1.54.0](https://github.com/tw93/Mole/releases/tag/V1.54.0) 为基线，使用 `mo status --json`；旧版本不支持时回退，不自动安装或升级。

默认模式不扫描整个主目录。工具调用采用有界等待，记录同一进程会话；默认快照超过 60 秒、预览超过 180 秒时检查进展，持续无进展则中断本次采集并报告不完整，不并发启动重复扫描。`--deep` 保留完整预览和错误信息供检查；大输出写入本次临时日志，最终仅汇总有依据的候选与限制。

体检不执行删除、kill、重启、模拟器 shutdown 或系统配置变更。已有授权仅覆盖明确对象和动作；需要处置时先核对活动任务与具体路径，再依据已有授权执行，缺少授权才询问。预览不删除候选，但 Mole 可能写入预览清单和日志；不得称为“零写入”。不自动 sudo、不添加 `--yes`。

## 读取快照

- 字段缺失、命令失败、空进程列表、沙箱拒绝访问均标为未知或采集受限，不填 0、不判正常。必要时使用平台许可的宿主只读采样。
- Mole 快照可能不含压缩内存或 APFS 可用量；当前症状或报告需要这些指标时，分别补 `vm_stat` 和 `df -k /System/Volumes/Data` / `diskutil apfs list`。不要以 total-used 推算 APFS 物理可用；未补采则报告未采集。
- `process_stale=true` 的进程与告警只能作为历史线索；同时显示 `collected_at` 和 `process_collected_at`。旧版无 freshness 字段时不能声称当前数据新鲜。
- `memory.used_percent` 是占用比例，不是内存压力。结合 `memory_pressure -Q`、压缩内存、Swap 增量与体感判断。`memory_pressure` 只用查询参数，不能使用施压选项。
- Swap total 是动态分配量，used/total 接近 100% 不等于物理内存耗尽；不按固定 Swap 占比触发清理或重启。`vm_stat` 的 Swapins/Swapouts 为启动以来计数，要看同一启动周期两次采样之差；字节换算使用输出中的 page size。
- 单进程 CPU 100% 约对应一个逻辑核，不能据此认定整机满载。先看总 CPU、核心数，再看持续占用和进程归属；大 RSS 本身不证明泄漏。
- 温度或风扇 0／缺失可能为传感器不可用或停转，不能判为低温健康。无电池设备不报电池故障；有蓝牙电量时才提醒低电量。
- APFS 卷共享容器，不能相加各挂载点用量。Simulator 只读镜像 97% 不构成磁盘告急证据。容量输出统一 GiB 或注明原始单位。

## 按症状补充证据

只运行当前症状所需检查，禁止为节省 token 而省掉核心证据。快照正常但症状持续时，间隔 5–10 秒补一次相关采样即可；时间序列不能由一张快照推断。

| 场景 | 定向检查 | 决策边界 |
| --- | --- | --- |
| 风扇响／发热／卡顿 | `top -l 2 -s 5 -n 0`；`ps -axo pid=,ppid=,%cpu=,rss=,comm=`；`pmset -g therm` | 区分整机 CPU、WindowServer 合成、浏览器/Electron 子进程、编译与测试。根据 PID/PPID 归属，不按名称批量 kill；一次高值不证明持续故障。 |
| 内存紧／Swap 增长 | `memory_pressure -Q`；`sysctl vm.swapusage`；`vm_stat`；按 RSS 查进程 | 同一时间窗口对照两次结果。先建议保存工作、停止已确认多余任务；重启是有条件选项，不以开机天数决定。禁止删除 `/private/var/vm/swapfile*`。 |
| 空间突然下降 | `df -k /System/Volumes/Data /System/Volumes/VM`；`diskutil apfs list`；`sysctl vm.swapusage`；`tmutil listlocalsnapshots /` | 对齐 APFS 物理可用、卷可用、Swap 与快照。系统“可供重要用途”容量可包含可清除空间，口径不同；无历史基线就不声称解释了全部下降量。必要时 `softwareupdate --history` 查近期更新。 |
| 模拟器／Xcode 占用 | `xcrun simctl list devices booted`；上述进程表中找真实 xcodebuild PID，再 `ps -p <PID> -o args=` 查 destination | Booted 不等于闲置；没发现 xcodebuild 也不等于无人使用。核对活跃 App/任务与 UDID，无法归属标未知。仅在明确授权后逐台 shutdown，复查 booted 和内存；不使用 shutdown all。 |
| 不休眠／空闲仍耗电 | `pmset -g assertions`；`pmset -g batt` | 查 Amphetamine、远控、媒体等 assertion 的进程和使用意图，不把正常保活一律当故障。 |

目录体积只在上面证据仍无法解释时，对一个已定位的路径做 `du -sh`（例如 `~/Library/Developer/CoreSimulator`），记录耗时并有界等待；不递归扫描所有虚拟挂载点。命令行参数可能包含敏感信息，只保留诊断必需片段。

## Mole 1.54 能力如何使用

新版增加慢机诊断线索、过期进程标记，以及飞书/Lark、微信/企业微信、Codex 崩溃报告、Playwright 遗留会话和 Xcode 测试克隆的清理保护。它们是候选发现能力，不是本机已经存在问题或全部安全可删的证明。

| 用户目的 | 可选命令（先核对本机 help） | 注意 |
| --- | --- | --- |
| 清理预览 | `mo clean --dry-run` | 保留跳过、权限不足、超时及部分结果；预估空间不是保证释放量。聊天数据、活动会话和手工未保存工作须保护。 |
| 查过去清理 | `mo history --json` | 记录可帮助定位动作；空历史不证明没有其他工具做过清理。 |
| 了解维护建议 | `mo optimize --dry-run` | 可补充 Swap、虚拟机、持续 CPU 线索；实际 optimize 会改缓存/服务，不自动执行。 |
| 项目构建产物 | `mo purge --dry-run` | 核对项目、Git 跟踪/嵌套仓库、密钥与活动构建；新版非交互清理要求 --yes，不将其作为绕过审阅的捷径。 |
| 安装包候选 | `mo installer --dry-run` | 仍需审阅是否需要保留离线安装包。 |
| 查某目录空间 | `mo analyze <path>` | 交互浏览器具有移动到废纸篓能力，并非所有交互都只读。只浏览，不执行删除键。 |
| 卸载 App | `mo uninstall --dry-run` | 先定位准确应用与关联数据；不能把删除 .app 当完整卸载，不能冒然清共享容器。 |

白名单管理、purge 扫描路径配置、Touch ID、升级和实际维护均为有副作用操作，不包含在体检内。旧版缺能力时说明限制；不要假定 dry-run 等于完整覆盖或无日志写入。

## 交付

先给结论和证据限制，再给紧凑表格：采样时间/来源、CPU、内存压力、压缩与 Swap、APFS 可用、关键进程及 freshness、可用的温度/电池数据。区分观察事实、待验证原因与建议。建议注明作用对象、是否需要授权，以及操作后复测哪项指标；没有清理就明确未清理。不要用健康总分覆盖局部异常，也不要复述全部原始输出。
