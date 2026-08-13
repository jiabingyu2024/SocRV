# 赛事 CoreMark 输入边界

当前比赛 profile 支持 `core_main_replacement`：赛事 C 文件的职责等同标准
CoreMark `core_main.c`，包含 `main()` 并依赖 `coremark.h`。构建时只把这个
`main()` 重命名为 `coremark_main()`，原文件不改动。

最终固件仍包含：

- RT-Thread、FinSH/MSH 和 `coremark [iterations]` 命令；
- 标准 `core_list_join.c`、`core_matrix.c`、`core_state.c`、`core_util.c`；
- SocRV 的 timer、UART、GPIO 和 CoreMark port；
- 本次运行目录中的赛事 CoreMark 驱动。

运行目录由以下命令生成：

```powershell
python scripts/prepare_competition_run.py --source "D:/competition_input/core_main.c"
```

配置写在 `competition_runs/<run-id>/source/competition.json`。比赛 profile 只接受：

```json
{
  "schema_version": 1,
  "mode": "core_main_replacement",
  "entry_source": "source/original/core_main.c",
  "extra_sources": [],
  "entry_symbol": "main"
}
```

如果赛事方提供多个算法文件、平台 port、自包含程序，或入口运行后不能返回，不能
继续使用这一 mode。先检查重复符号、计时接口、迭代参数和返回 MSH 的条件，再增加
专用 adapter。`source/original/` 始终保留赛事原文件。
