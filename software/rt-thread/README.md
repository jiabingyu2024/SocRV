# RT-Thread dependency

SocRV 固定使用 RT-Thread `v3.1.5`：

```text
commit 92beddf3bccf6346e26aa097f82464456fb8e6bd
```

`dependency.lock.json` 是版本与稀疏检出范围的权威来源。官方源码通过以下命令放到被 Git 忽略的 `upstream/`：

```text
make deps
make deps-check
```

SocRV 自己的启动、Board/BSP 适配和 `rtconfig.h` 位于
`software/rt-thread/port/`，不直接修改 `upstream/`。当前配置启用 heap、
machine timer tick、software interrupt、components init 与 FinSH/MSH；
应用和命令位于 `software/applications/rtthread/`。
