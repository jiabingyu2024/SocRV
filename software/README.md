# Software

`software/` 保存 SocRV 的启动代码、链接布局、BSP、裸机应用和 RT-Thread
依赖描述。当前 `smoke` 镜像用于验证 demo core 与完整 SoC 通路。

在 WSL 中构建：

```sh
make -C software APP=smoke OUT=../build/software/baremetal-smoke
```

ELF 的 `CODE` 和 `DATA` 段分别位于 `0x0000_0000` 与
`0x1000_0000`，随后由 `scripts/elf2mem.py` 转换为两个独立内存镜像。
