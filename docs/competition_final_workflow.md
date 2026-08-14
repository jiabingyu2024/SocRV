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

Kintex 只修改 `set CORE_MHZ 150` 选择频率，不手动设置 MMCM 倍频和分频参数。

如果这次实现已经通过时序和实板验证，可以将同一次实现的文件整理成路线二使用的黄金目录：

```text
golden.bit
golden.mmi
golden_postroute.dcp
bram_map.tsv
mmi_validation.json
```

## 路线二：复用已有布局布线结果，直接生成新 bitstream

当硬件完全不变、只有软件变化，并且已经存在匹配的黄金目录时，使用这条路线。

这条路线使用两个目录：

- 新 run 目录：提供新软件的 `code.mem` 和 `data.mem`；
- 旧 run 的黄金目录：提供原布局布线对应的 `golden.bit` 和 `golden.mmi`。

### 1. 在 PowerShell 中准备并构建新软件

```powershell
python scripts/prepare_competition_run.py --source software/coremark/upstream/core_main.c --run-id coremark_rtos_sensors_patch_20260814_01
python scripts/build_software.py --profile contest-rtthread-coremark --run-dir competition_runs/coremark_rtos_sensors_patch_20260814_01
```

### 2. PYNQ-Z2 50 MHz：使用旧黄金目录生成新 bitstream

```powershell
python scripts/patch_bitstream.py --golden-dir competition_runs/sensor_fix_bh1750_oled_20260814_01/golden/pynq_z2-rtthread-coremark-50mhz --code-mem competition_runs/coremark_rtos_sensors_patch_20260814_01/images/code.mem --data-mem competition_runs/coremark_rtos_sensors_patch_20260814_01/images/data.mem --output-dir competition_runs/coremark_rtos_sensors_patch_20260814_01/patched/pynq_z2-50mhz
```

输出：

```text
competition_runs/coremark_rtos_sensors_patch_20260814_01/patched/pynq_z2-50mhz/competition.bit
```

### 3. Kintex-7 150 MHz：使用旧黄金目录生成新 bitstream

```powershell
python scripts/patch_bitstream.py --golden-dir competition_runs/sensor_fix_bh1750_oled_20260814_01/golden/kintex7-rtthread-coremark-150mhz --code-mem competition_runs/coremark_rtos_sensors_patch_20260814_01/images/code.mem --data-mem competition_runs/coremark_rtos_sensors_patch_20260814_01/images/data.mem --output-dir competition_runs/coremark_rtos_sensors_patch_20260814_01/patched/kintex7-150mhz
```

输出：

```text
competition_runs/coremark_rtos_sensors_patch_20260814_01/patched/kintex7-150mhz/competition.bit
```

路线二不会修改 DCP，也不会启动 Vivado。它只根据 `golden.mmi`，把新软件镜像写入已有布局布线对应的 `golden.bit`。

> 当前工作区尚未发现完整的 `golden.bit` 和 `golden.mmi` 黄金目录。上面的 `sensor_fix_bh1750_oled_20260814_01/golden/...` 是建议归档位置；必须先用路线一生成并整理匹配的黄金包，路线二才能执行。

## 选择路线

```text
硬件、RTL、XDC、板卡、频率或内存结构变化
    → 路线一

只有软件变化，并且已有完全匹配的黄金目录
    → 路线二
```

PYNQ-Z2 与 Kintex-7 的黄金 bit、MMI、DCP 不能混用，不同频率也不能混用。
