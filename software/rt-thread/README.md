# RT-Thread dependency

SocRV 固定使用 RT-Thread `v5.2.2`：

```text
commit ddf52e2cdd977f14fc04035c88672ac204aec713
```

`dependency.lock.json` 是版本与稀疏检出范围的权威来源。官方源码通过以下命令放到被 Git 忽略的 `upstream/`：

```text
make deps
make deps-check
```

SocRV 自己的 CPU Port、Board Port 和配置文件放在 `software/rt-thread/` 的受控目录中，不直接修改 `upstream/`。
