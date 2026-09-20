# Mac Health Check

用于 Codex / Claude Code 的 Mac 诊断 skill。优先读取 Mole JSON，失败或缺 Mole/jq 时回退到 macOS 原生命令。覆盖风扇、WindowServer、内存与 Swap、APFS 空间骤降、Xcode/模拟器和保活进程；具体流程见 [SKILL.md](SKILL.md)。

## 使用

从实际安装目录运行，不依赖固定的用户目录大小写：

```bash
bash scripts/health.sh
bash scripts/health.sh --deep  # 按需清理预览，不删除候选
```

自然语言「电脑慢」「风扇响」「磁盘空间突然少了」进入诊断；「看看能清理多少」才追加预览。脚本不安装依赖、不结束进程、不修改系统设置。Mole 的预览本身可能写清单和日志，耗时也可能较长；按照 skill 的有界等待规则运行。

可选依赖为 Mole 和 jq；安装属于单独动作：`brew install mole jq`。本版于 2026-09-20 对照 [Mole V1.54.0 发布说明](https://github.com/tw93/Mole/releases/tag/V1.54.0) 和本机 1.54.0 的 help/JSON 验证。未对所有历史版本做兼容认证；不支持 `status --json` 时显示错误并回退。

## 输出与限制

- Mole 健康分是参考；内存使用比例不等于压力，动态 Swap 分配比例不用于判“告急”。
- 缺失探针、空进程数据与 stale 标记可见；温度/风扇 0 不当作正常证据。
- APFS 共享容器与 Simulator 镜像不重复计容；空间变化需要同口径、同时段的证据。
- 默认输出紧凑状态；清理预览保留原始警告和退出码，避免提取总量时隐藏扫描失败。
- `analyze` 具有删除交互，`optimize` 会维护系统，其他清理命令也并非天然只读。按具体授权执行。

## 验证

```bash
python3 -m unittest discover -s tests -v
bash -n scripts/health.sh scripts/sysmon.sh
git diff --check
```

测试使用临时目录与模拟命令覆盖 JSON 缺失/过期、回退、预览失败和调用边界，不清理本机文件。真实宿主采样与故障注入分别报告；测试通过不证明任何候选可删除。
