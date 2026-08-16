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

### 4. AXKU062 100 MHz：使用旧黄金目录生成新 bitstream

```powershell
python scripts/patch_bitstream.py --golden-dir competition_runs/sensor_fix_bh1750_oled_20260814_01/golden/axku062-rtthread-coremark-100mhz --code-mem competition_runs/coremark_rtos_sensors_patch_20260814_01/images/code.mem --data-mem competition_runs/coremark_rtos_sensors_patch_20260814_01/images/data.mem --output-dir competition_runs/coremark_rtos_sensors_patch_20260814_01/patched/axku062-100mhz
```

输出：

```text
competition_runs/coremark_rtos_sensors_patch_20260814_01/patched/axku062-100mhz/competition.bit
```

使用其他 AXKU062 频率时，黄金目录和输出目录中的频率必须同步替换，并且黄金包
必须来自同一板卡、同一频率和同一套 RTL/XDC/内存结构。

路线二不会修改 DCP，也不会启动 Vivado。它只根据 `golden.mmi`，把新软件镜像写入已有布局布线对应的 `golden.bit`。

> 当前工作区尚未发现完整的 `golden.bit` 和 `golden.mmi` 黄金目录。上面的 `sensor_fix_bh1750_oled_20260814_01/golden/...` 是建议归档位置；必须先用路线一生成并整理匹配的黄金包，路线二才能执行。

## 选择路线

```text
硬件、RTL、XDC、板卡、频率或内存结构变化
    → 路线一

只有软件变化，并且已有完全匹配的黄金目录
    → 路线二
```

PYNQ-Z2、Kintex-7 与 AXKU062 的黄金 bit、MMI、DCP 不能混用，不同频率也不能混用。
