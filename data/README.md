# Controlled data

`data/` 保存会影响构建或测试结果、但不属于 RTL/Software 源码的受控输入。

```text
isa/        从上一轮工程导入的 RISC-V ISA 测试数据及 hash manifest
profiles/   跨 Software、Sim、FPGA 的系统级 Profile
schemas/    Board、Profile、Image、Testlist、Result 的 schema
tests/      UART/GPIO/Memory 等测试 stimulus
expected/   较大的 golden/reference payload
reference/  有明确来源的参考输入
```

普通 ELF、MEM、波形、日志和报告进入 `build/`，不写回本目录。

ISA 数据通过以下命令导入和检查：

```text
make data-isa-import
make data-isa-check
```

`data/isa/manifest.json` 记录每个文件的大小和 SHA-256。
