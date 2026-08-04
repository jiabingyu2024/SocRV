# Controlled data

`data/` 保存影响构建或验证结果、但不属于 RTL/Software 源码的受控输入。

```text
soc/        Memory Map 与软件可见硬件合同的唯一事实源
isa/        从锁定官方 riscv-tests 生成的 RV32UI 数据集
profiles/   跨 Software、Sim、FPGA 的系统级 Profile
schemas/    Contract、Image、Build、ISA、Testlist、Result 等 schema
tests/      受控 SoC 回归清单
expected/   较大的 golden/reference payload
reference/  有明确来源的参考输入
```

`data/isa/manifest.json` 记录 riscv-tests commit、Memory Map hash、选择与
排除项以及每个 ELF/镜像的 SHA-256。它必须通过生成器更新：

```text
make deps
make isa-data
make isa-data-check
make isa-regression
```

旧工程 ISA 文件不再是默认输入；需要审计旧数据时使用显式的
`data-isa-legacy-import`/`data-isa-legacy-check`。普通 ELF、MEM、波形、
日志和报告进入 `build/`。
