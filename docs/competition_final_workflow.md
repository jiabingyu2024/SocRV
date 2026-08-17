# SocRV 最终构建流程：两条路线

最终基线固定为：RT-Thread + MSH + CoreMark + BH1750 + OLED + PL UART。

默认 CoreMark 入口文件：

```text
software/coremark/upstream/core_main.c
```

## 使用规则

- Python 命令在项目根目录 `SocRV` 的 Windows PowerShell 中执行，使用项目内相对路径。
- Vivado 命令在 Windows GUI 版 Vivado 的 Tcl Console 中执行，`source` 使用绝对路径。
- 命令直接写 run 名称和文件路径，不使用 PowerShell 中间变量。
- 每次新构建都换一个新的 run 名称，不要复用已有目录。

旧版本 `prepare_competition_run.py` 使用 Windows owner-only 临时目录生成 run，可能
导致 Vivado 读取 launcher 时出现 `permission denied`。这不是 Tcl 路径或 Vivado
`source` 语法问题。旧 run 需要在管理员 PowerShell 中接管目录所有权并恢复继承，
修复脚本会完成这两步：

```powershell
python scripts/repair_competition_run_permissions.py --run-dir competition_runs/<run-id>
```

普通 PowerShell 如果提示需要管理员权限，应关闭当前终端，右键 PowerShell 选择
“以管理员身份运行”，进入仓库目录后重新执行同一条命令。

新版本使用继承 `competition_runs` 权限的普通 staging 目录，不再产生该 ACL。

下面的命令使用具体 run 名称，可以直接复制；下一次构建时只需把同一路线中的 run 名称整体替换掉。

## 路线一：重新综合、布局布线并生成 bitstream

当 RTL、XDC、板卡、频率、传感器接口或内存结构变化时，使用这条路线。

### 1. 在 PowerShell 中准备并构建软件

```powershell
python scripts/prepare_competition_run.py --source software/coremark/upstream/core_main.c --run-id coremark_rtos_sensors_20260814_02
python scripts/build_software.py --profile contest-rtthread-coremark --run-dir competition_runs/coremark_rtos_sensors_20260814_02
```

如果 CoreMark 入口文件发生变化，直接把 `--source` 后面的相对路径换成实际文件路径。

该 profile 会把 RT-Thread、CoreMark、BH1750、OLED 和四条 MSH 命令构建到同一份固件中：

```text
coremark
light_read
oled_start
oled_stop
```

### 2. PYNQ-Z2：在 Vivado GUI Tcl Console 中创建工程

```tcl
source {E:/Resources/03_competitions/26_03_jcs/2608round/subprj2/SocRV/competition_runs/coremark_rtos_sensors_20260814_02/vivado/create_pynq_z2_project.tcl}
```

随后在 Flow Navigator 中依次执行：

```text
Run Synthesis → Run Implementation → Generate Bitstream
```

PYNQ 固定为 50 MHz，结果位于：

```text
competition_runs/coremark_rtos_sensors_20260814_02/vivado/pynq_z2-50mhz/project/
```

### 3. Kintex-7：在 Vivado GUI Tcl Console 中创建工程

```tcl
set CORE_MHZ 150
source {E:/Resources/03_competitions/26_03_jcs/2608round/subprj2/SocRV/competition_runs/coremark_rtos_sensors_20260814_02/vivado/create_kintex7_project.tcl}
```

随后同样执行：

```text
Run Synthesis → Run Implementation → Generate Bitstream
```

150 MHz 结果位于：

```text
competition_runs/coremark_rtos_sensors_20260814_02/vivado/kintex7-150mhz/project/
```

Kintex-7 支持从 100 MHz 到 250 MHz、以 10 MHz 为步进选择核心频率：

```text
100 / 110 / 120 / 130 / 140 / 150 / 160 / 170 /
180 / 190 / 200 / 210 / 220 / 230 / 240 / 250 MHz
```

只修改 `set CORE_MHZ 150` 中的整数选择频率，不手动设置 MMCM 倍频和分频参数；
所有频率下外设时钟仍固定为 50 MHz。

### 4. AXKU062：在 Vivado GUI Tcl Console 中创建工程

```tcl
set CORE_MHZ 100
source {E:/Resources/03_competitions/26_03_jcs/2608round/subprj2/SocRV/competition_runs/coremark_rtos_sensors_20260814_02/vivado/create_axku062_project.tcl}
```

随后同样执行：

```text
Run Synthesis → Run Implementation → Generate Bitstream
```

100 MHz 结果位于：

```text
competition_runs/coremark_rtos_sensors_20260814_02/vivado/axku062-100mhz/project/
```

AXKU062 在 competition workflow 中同样支持从 100 MHz 到 250 MHz、以 10 MHz
为步进选择核心频率。只修改 `set CORE_MHZ` 选择频率，不手动设置 MMCM 倍频和
分频参数；所有频率下外设时钟仍固定为 50 MHz。AXKU062 原有的 50 MHz
正确性测试配置继续保留，但不属于 100–250 MHz 的比赛频率扫描区间。

AXKU062 板载 I2C 总线为 1.8 V，当前连接的是 LM75 和 24LC04。最终基线如果必须
连接 3.3 V BH1750/OLED，需要先确认可用扩展引脚、电平转换和对应 XDC，不能直接
将外部 3.3 V 上拉接到现有 1.8 V I2C 总线。

三个板卡的 `create_project.tcl` 都为 `impl_1` 配置了 bitstream 生成后的 post-hook。
因此，使用这些 Tcl 重新创建工程后，无论是在 GUI 中点击 `Generate Bitstream`，还是
由脚本启动同一个 `impl_1`，成功写出 bitstream 后都会自动在板卡构建目录中生成：

```text
bram_map.tsv
```

例如 PYNQ-Z2 的 base Vivado 构建目录天然包含：

```text
competition_runs/coremark_rtos_sensors_20260814_02/vivado/pynq_z2-50mhz/
├── bram_map.tsv
└── project/socrv.runs/impl_1/fpga_top.bit
```

旧工程如果是在接入 post-hook 之前创建的，不会自动获得这项设置。应使用当前路线一
Tcl 重新创建工程并重新生成一次 bitstream；或者在旧工程中手动为 `impl_1` 设置
`STEPS.WRITE_BITSTREAM.TCL.POST` 后再生成一次。只有 bitstream 成功生成且 hook
确认导出了 48 个 ICCM/DCCM BRAM，`bram_map.tsv` 才会保留。

## 路线二：复用已有布局布线结果，直接生成新 bitstream

当硬件完全不变、只有软件变化，并且已经存在匹配的 base Vivado 构建目录时，使用这条路线。

这条路线使用两个目录：

- `base_dir`：路线一已有的板卡 Vivado 构建目录，提供原布局布线生成的
  `project/socrv.runs/impl_1/fpga_top.bit` 和 `bram_map.tsv`；
- `out_dir`：新软件 run 的根目录，软件构建先在其中生成 `images/code.mem` 和
  `images/data.mem`，补丁结果也直接写入这个目录。

`out_dir` 可以包含软件构建的其他文件，但在执行补丁前不能已有
`competition.bit` 或 `patch_result.json`，脚本会拒绝覆盖这两个结果。

### 1. 在 PowerShell 中准备并构建新软件

```powershell
python scripts/prepare_competition_run.py --source software/coremark/upstream/core_main.c --run-id target
python scripts/build_software.py --profile contest-rtthread-coremark --run-dir competition_runs/target
```

确认下面两个文件存在后再执行补丁：

```text
competition_runs/target/images/code.mem
competition_runs/target/images/data.mem
```

### 2. PYNQ-Z2 50 MHz：使用已有 base 生成新 bitstream

```powershell
python scripts/patch_bitstream.py --base-dir competition_runs/sensor_fix_bh1750_oled_20260814_01/vivado/pynq_z2-50mhz --out-dir competition_runs/target
```

### 3. Kintex-7 150 MHz：使用已有 base 生成新 bitstream

```powershell
python scripts/patch_bitstream.py --base-dir competition_runs/sensor_fix_bh1750_oled_20260814_01/vivado/kintex7-150mhz --out-dir competition_runs/target
```

### 4. AXKU062 100 MHz：使用已有 base 生成新 bitstream

```powershell
python scripts/patch_bitstream.py --base-dir competition_runs/sensor_fix_bh1750_oled_20260814_01/vivado/axku062-100mhz --out-dir competition_runs/target
```

以上三条板卡命令按目标板卡三选一，不要对同一个 `out_dir` 连续执行。三者的统一输出为：

```text
competition_runs/target/competition.bit
competition_runs/target/patch_result.json
```

`patch_result.json` 记录 base bit、BRAM map、软件镜像、每一步更新和最终 bitstream
的 SHA-256，便于确认产物来自哪一个 base 和哪一份软件。

使用其他 Kintex-7 或 AXKU062 频率时，只替换 `base_dir` 中对应的频率目录。
base 必须来自同一板卡、同一频率和同一套 RTL/XDC/内存结构。

路线二不会修改 base 工程或 DCP，也不会启动 Vivado。它根据 `base_dir/bram_map.tsv`
在临时目录生成 MMI，再用 `updatemem` 把 `out_dir` 的新软件镜像写入 base bitstream；
临时 MMI 和中间 bitstream 会在成功或失败后清理。

> 如果 `base_dir/bram_map.tsv` 不存在，说明该工程尚未成功执行当前 post-hook，
> 不能只凭一个旧 bitstream 执行路线二。

## 选择路线

```text
硬件、RTL、XDC、板卡、频率或内存结构变化
    → 路线一

只有软件变化，并且已有完全匹配的 base Vivado 构建目录
    → 路线二
```

PYNQ-Z2、Kintex-7 与 AXKU062 的 base bitstream 和 BRAM map 不能混用，不同频率也不能混用。
