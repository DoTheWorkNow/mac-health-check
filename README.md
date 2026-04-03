# Mac Health Check

Claude Code skill — 一键诊断 Mac 系统健康状况。

一次 Bash 调用采集内存、CPU、磁盘、电池、进程占用数据，Claude 解读后给出中文诊断报告和可操作的优化建议。

## 效果

说「电脑好慢」「风扇在转」「内存占用高」即可触发，输出示例：

```
## 系统概览
| 指标 | 状态 |
|------|------|
| 内存 | 25.3/32GB (81%) — 紧张 |
| CPU  | 60% idle — 偏忙 |
| 磁盘 | 12/995GB — 充足 |
| 电池 | 100% 充电中 |

## 占用大户
| 进程 | 内存 | CPU | 说明 |
|------|------|-----|------|
| YunshuManager | 1133MB | 106% | CPU 和内存双高 |
| ...

## 建议
- YunshuManager 占用过高，建议关闭
- ...
```

## 安装

将此仓库克隆到 Claude Code skills 目录：

```bash
git clone https://github.com/DoTheWorkNow/mac-health-check.git ~/.claude/skills/mac-health-check
```

## 文件结构

```
mac-health-check/
├── SKILL.md              # Skill 定义（触发条件、输出格式、判断标准）
├── scripts/
│   └── sysmon.sh         # 系统数据采集脚本
└── README.md
```

## 设计思路

- **一次调用**：`sysmon.sh` 在 shell 层完成所有采集和格式化，Claude 只需一次 Bash 调用
- **省 token**：脚本输出紧凑的结构化文本，避免冗余
- **安全**：只读取系统状态，不执行任何修改操作；清理进程前会先列出让用户确认

## License

MIT
