# SocRV 光照模块与 OLED 接入详细规划

> 状态：PYNQ-Z2 与 Kintex-7 双板第一版均已实现，等待 Vivado 和实物上板验证。
>
> 本文记录双板硬件接线、RTL 接口、驱动分层、MSH 命令、验证方法、实现状态和验收标准。

## 1. 目标与范围

本次在 PYNQ-Z2 和 Kintex-7 competition 两个 FPGA 目标上接入同一组 I²C 设备：

1. GY-302 光照强度模块，传感器芯片为 BH1750；
2. 0.96 英寸、128×64、四针 I²C OLED，用于显示固定文本 `RTThread`。

最终对用户只提供三条 MSH 命令：

| 命令 | 最终行为 |
|---|---|
| `light_read` | 发起一次 BH1750 单次测量，并在串口打印设备地址、原始值、lux 结果和错误状态 |
| `oled_start` | 初始化 OLED、清屏并显示 `RTThread`，将 OLED 状态置为运行 |
| `oled_stop` | 关闭 OLED 显示并禁止后续刷新，但不关闭共享 I²C 控制器，也不影响 BH1750 |

开发期间可以在单元测试或调试固件中保留地址探测、总线恢复和寄存器自检入口，但不得把下列临时命令导出到最终 MSH：

- `lux_loop`
- `oled_test`
- `oled_addr`
- `sensor_demo`
- `i2c_scan`

地址扫描和控制器探测只属于开发阶段内部测试，不属于最终用户接口。

## 2. 当前工程边界

### 2.1 处理器和软件仍全部位于 PL

I²C 控制器作为 SocRV 的新 MMIO 外设接入 `local_peripheral_subsystem`。BH1750/OLED 驱动和 MSH 命令运行在 PL 内的自研 RISC-V 与 RT-Thread 上，不使用 ARM 应用、Linux、PS AXI 或 PS I²C。

两个目标的处理器、I²C 外设、驱动和 RT-Thread 都位于 PL。当前 PYNQ-Z2 工程仍由 H16 的 125 MHz 板级时钟经 MMCM 产生 50 MHz SoC 时钟；Kintex-7 由 AD12/AD11 的 200 MHz 差分时钟经 MMCM 产生核心和 50 MHz 外设时钟。此前讨论的 PS7 `FCLK_CLK0` 与 `lock_loss_sticky` 尚未恢复到当前工作树，属于独立的时钟修复任务，不能把本文的传感器接入状态误认为该时钟方案已完成。

### 2.2 第一版使用轮询，不增加传感器中断

BH1750 和当前四针 OLED 都不需要额外中断脚。第一版 I²C 控制器采用有界超时的轮询方式，避免为了两个低速设备修改 EH1 外部中断分配。若以后确实需要 I²C 中断，再单独更新中断合同和 RT-Thread ISR，不在本次范围内。

### 2.3 不允许传感器故障复位 SocRV

I²C NACK、总线忙、SCL/SDA 被拉低或设备掉线只返回驱动错误，不得连接到 SoC 全局复位或板载 LED 故障逻辑。PYNQ-Z2 当前 LED2 仍表示 FAIL，并不是 `lock_loss_sticky`；传感器实现不得改变现有 LED 含义。

## 3. 已知信息与待确认项

### 3.1 BH1750 / GY-302

| 项目 | 规划值 |
|---|---|
| 接口 | I²C |
| ADDR 接低 | 7-bit 地址 `0x23` |
| ADDR 接高 | 7-bit 地址 `0x5C` |
| 推荐接法 | ADDR 接 GND，固定使用 `0x23` |
| 初始测量模式 | One Time H-Resolution Mode，命令 `0x20` |
| 换算 | `lux = raw / 1.2`，软件使用定点数计算 |

驱动和打印统一使用 7-bit 地址，不把读写位包含在地址中。

### 3.2 OLED 地址 `0x78` / `0x7A`

模块背面的 `0x78` 和 `0x7A` 很可能是包含最低读写位的 8-bit 写地址：

```text
0x78 >> 1 = 0x3C
0x7A >> 1 = 0x3D
```

因此控制器和驱动应尝试的 7-bit 地址是 `0x3C` 和 `0x3D`，不能直接把 `0x78` 或 `0x7A` 写入 7-bit 地址寄存器。模块通常只会通过焊盘/电阻选择其中一个地址，并不是同时响应两个地址。

这仍需上板确认。开发阶段由内部探测逻辑依次检查 `0x3C`、`0x3D` 的 ACK；最终用户不需要也不应通过 `oled_addr` 命令手工设置地址。

### 3.3 OLED 控制器型号

0.96 英寸 128×64 I²C OLED 常见控制器是 SSD1306，但仅凭尺寸和背面地址不能排除 SH1106 等兼容芯片。第一版按 SSD1306 初始化，并把下列差异隔离在设备驱动内部：

- 初始化命令表；
- 显存列数和列偏移；
- 页/列寻址方式；
- `set_window` 和 framebuffer 刷新函数。

如果实物出现整体横向偏移、边缘丢列或初始化后无显示，应先核对控制器型号，再切换 SH1106 兼容路径；不要通过反复修改通用 I²C RTL来猜控制器。

## 4. 推荐接线

两个模块在每块板上都并联到同一组 I²C 总线。PYNQ-Z2 使用 PMODB，避开可能安装在 Arduino 接口上的 EES_363DP 子卡；Kintex-7 使用 J10 的 DEBUG_39/40。

### 4.1 总线引脚

| 板卡 | 用途 | 板级接口 | 板级网络 | FPGA 封装脚 | FPGA 方向 |
|---|---|---|---|---|---|
| PYNQ-Z2 | I²C SCL | PMODB-1 | JB1_P | W14 | `inout`，开漏 |
| PYNQ-Z2 | I²C SDA | PMODB-2 | JB1_N | Y14 | `inout`，开漏 |
| PYNQ-Z2 | GND | PMODB-5 或 11 | GND | - | 电源地 |
| PYNQ-Z2 | 3.3 V | PMODB-6 或 12 | 3V3 | - | 模块供电 |
| Kintex-7 | I²C SCL | J10-9 | DEBUG_39 | F22 | `inout`，开漏 |
| Kintex-7 | I²C SDA | J10-10 | DEBUG_40 | G22 | `inout`，开漏 |
| Kintex-7 | GND | J10-11 至 19 任一 | GND | - | 电源地 |
| Kintex-7 | 3.3 V | J10-20 | 3V3 | - | 模块供电 |

### 4.2 BH1750 接线

| GY-302 丝印 | PYNQ-Z2 连接 | Kintex-7 连接 |
|---|---|---|
| VCC | PMODB-6 或 12，3.3 V | J10-20，3.3 V |
| GND | PMODB-5 或 11 | J10-11 至 19 任一 |
| SCL | PMODB-1 / W14 | J10-9 / F22 |
| SDA | PMODB-2 / Y14 | J10-10 / G22 |
| ADDR | GND，使用 7-bit 地址 `0x23` | GND，使用 7-bit 地址 `0x23` |

### 4.3 OLED 接线

| OLED 丝印 | PYNQ-Z2 连接 | Kintex-7 连接 |
|---|---|---|
| GND | PMODB-5 或 11 | J10-11 至 19 任一 |
| VCC | PMODB-6 或 12，3.3 V | J10-20，3.3 V |
| SCL | PMODB-1 / W14，与 BH1750 并联 | J10-9 / F22，与 BH1750 并联 |
| SDA | PMODB-2 / Y14，与 BH1750 并联 | J10-10 / G22，与 BH1750 并联 |

实物插线必须以模块 PCB 上的 `GND/VCC/SCL/SDA` 丝印为准，不能根据照片朝向猜针序。

### 4.4 电气检查

I²C 必须按开漏总线实现：FPGA 只能主动拉低，释放时输出高阻，由外部上拉产生高电平。

上板前依次检查：

1. Kintex-7 先测量 TP5，只有确认 Bank 17 的 VADJ1 为 3.3 V，才可使用当前 `LVCMOS33` XDC 并把模块总线直接上拉到 3.3 V；若不是 3.3 V，必须先增加双向 I²C 电平转换；
2. 两个模块先只用 3.3 V 供电，不接 5 V；
3. 断电测量 SCL、SDA 到 3.3 V 的等效上拉电阻；
4. 如果两个模块均无上拉，SCL 和 SDA 各增加约 4.7 kΩ 到与 FPGA I/O 电压匹配的电源；
5. 如果两个模块都自带上拉，计算并联后的等效阻值，避免过强上拉；
6. FPGA 释放总线后测量空闲电平，应接近 3.3 V，不得被任何模块拉到 5 V；
7. 第一版固定 100 kHz，用示波器或逻辑分析仪检查上升沿、START、ACK 和 STOP。

两个目标的 XDC：

```tcl
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports sensor_i2c_scl_io]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports sensor_i2c_sda_io]

# Kintex-7：仅当 TP5 实测 VADJ1=3.3 V 时使用 LVCMOS33
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVCMOS33} [get_ports sensor_i2c_scl_io]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS33} [get_ports sensor_i2c_sda_io]
```

## 5. 总体架构

```text
MSH
├─ light_read ──> BH1750 驱动 ─┐
├─ oled_start ──> OLED 驱动 ───┼─> I²C BSP 驱动 ─> MMIO I²C Master RTL
└─ oled_stop  ──> OLED 驱动 ───┘                         │
                                                         ├─ PYNQ: W14/Y14（开漏）
                                                         └─ Kintex: F22/G22（开漏）
                                                              │
                                                ┌─────────────┴─────────────┐
                                                │                           │
                                        BH1750 @ 0x23           OLED @ 0x3C/0x3D
```

总线只有一个主机，即 SocRV I²C 控制器。BH1750 和 OLED 共用同一个 RT-Thread mutex，任何一笔复合事务从 START 到 STOP 都必须持有该锁，防止两条 MSH 命令交叉发送字节。

## 6. RTL 规划

### 6.1 新增 I²C MMIO 外设

建议分配新的 4 KiB 地址窗口：

| 外设 | 基地址 | 大小 |
|---|---:|---:|
| I2C | `0x1000_4000` | `0x1000` |

该地址紧跟现有 `SYSCTRL 0x1000_3000`，不会改变已有 TIMER/UART/GPIO/SYSCTRL 地址。

建议寄存器合同如下，最终实现时以 `data/soc/software_contract.json` 为唯一软件合同来源：

| 偏移 | 名称 | 访问 | 关键含义 |
|---:|---|---|---|
| `0x00` | `CONTROL` | RW | bit0 使能控制器；bit1 软件复位事务状态机；bit2 发起总线恢复 |
| `0x04` | `STATUS` | RO/W1C | busy、done、addr_nack、data_nack、timeout、arb_lost、bus_stuck、SCL/SDA 采样值 |
| `0x08` | `CLOCK_DIV` | RW | 从 50 MHz 外设时钟产生 100 kHz SCL 的分频值 |
| `0x0C` | `TXDATA` | RW | 待发送字节 |
| `0x10` | `RXDATA` | RO | 最近接收字节 |
| `0x14` | `COMMAND` | WO | START、重复 START、WRITE、READ_ACK、READ_NACK、STOP |
| `0x18` | `TIMEOUT` | RW | 单阶段最大等待周期，禁止无限 busy |

若状态机使用 4 倍 SCL 的内部节拍，推荐定义：

```text
SCL = peripheral_clock / (4 × (CLOCK_DIV + 1))
```

50 MHz、100 kHz 时 `CLOCK_DIV=124`。分频公式、复位值和软件头文件必须一致，不能只在注释里约定。

### 6.2 I²C 状态机能力

第一版必须支持：

- START 和重复 START；
- STOP；
- 发送地址和数据字节；
- 采样从机 ACK/NACK，并区分地址 NACK 与数据 NACK；
- 接收字节并由主机发送 ACK/NACK；
- SCL 释放后读取实际引脚，支持有限的 clock stretching；
- 每个阶段有超时，超时后尝试产生 STOP；
- 仲裁丢失检测：计划输出高而 SDA 实际为低时终止事务；
- 总线恢复：SDA 被卡低时最多释放/脉冲 SCL 9 次，再生成 STOP；
- 所有错误保持到软件 W1C 清除，不触发 SoC 复位。

第一版不需要 FIFO、DMA、多主机性能优化或 I²C 中断。

### 6.3 开漏顶层连接

控制器内部建议使用三组信号：

```systemverilog
logic scl_drive_low;
logic sda_drive_low;
logic scl_i;
logic sda_i;
```

顶层只能按下面的逻辑驱动：

```systemverilog
assign sensor_i2c_scl_io = scl_drive_low ? 1'b0 : 1'bz;
assign sensor_i2c_sda_io = sda_drive_low ? 1'b0 : 1'bz;
assign scl_i = sensor_i2c_scl_io;
assign sda_i = sensor_i2c_sda_io;
```

禁止写成普通推挽 `0/1` 输出。综合阶段还应检查最终网表中两个端口确实为三态输出。

### 6.4 工程接入点

预计修改/新增：

| 文件 | 规划改动 |
|---|---|
| `rtl/soc/i2c_master.sv` | 新增 MMIO 寄存器和 I²C 主状态机 |
| `rtl/soc/soc_memory_map_pkg.sv` | 增加 I2C 基地址和窗口大小 |
| `rtl/soc/local_peripheral_subsystem.sv` | 增加地址译码、读返回和 I²C 实例 |
| `rtl/soc/soc_top.sv` | 暴露 I²C 开漏控制/采样端口 |
| `fpga/boards/pynq_z2/rtl/fpga_top.sv` | 增加 `sensor_i2c_scl_io/sda_io` 顶层端口和三态连接 |
| `fpga/boards/pynq_z2/constraints/pins.xdc` | 绑定 W14/Y14 |
| `fpga/boards/kintex7_competition/rtl/fpga_top.sv` | 增加相同的 I²C 顶层端口和三态连接 |
| `fpga/boards/kintex7_competition/constraints/pins.xdc` | 绑定 F22/G22，并注明 VADJ1 前置检查 |
| `rtl/filelist.f`、仿真 filelist | 纳入新 RTL |
| `data/soc/memory_map.json` | 增加 I2C 地址窗口 |
| `data/soc/software_contract.json` | 增加寄存器、位定义和副作用 |

修改合同后运行生成器，禁止手改生成头文件：

```powershell
python scripts/generate_soc_contract.py
python scripts/generate_soc_contract.py --check
python scripts/validate_schemas.py
```

## 7. BSP 与设备驱动规划

### 7.1 文件分层

建议新增：

```text
software/bsp/include/drv_i2c.h
software/bsp/drivers/drv_i2c.c
software/bsp/include/drv_bh1750.h
software/bsp/drivers/drv_bh1750.c
software/bsp/include/drv_oled.h
software/bsp/drivers/drv_oled.c
software/applications/rtthread/commands/cmd_sensors.c
```

`software/profiles/rtthread_sources.inc` 需要显式加入这些源文件。裸机 profile 不应被无条件带入 RT-Thread mutex 和 FinSH 依赖。

### 7.2 通用 I²C BSP

`drv_i2c` 负责：

- 初始化 100 kHz 分频和事务超时；
- `start`、`restart`、`write_byte`、`read_byte`、`stop`；
- 7-bit 地址加读写位；
- 等待 busy/done，统一清除 W1C 状态；
- 把硬件状态转换为稳定的软件错误码；
- 在 RT-Thread 下用 mutex 串行化整笔事务；
- 错误路径保证释放 mutex，并尽力产生 STOP；
- 总线恢复只在检测到 bus_stuck 时执行，不在每次设备 NACK 后盲目复位控制器。

建议错误枚举至少包含：

```text
I2C_OK
I2C_ERR_INVALID
I2C_ERR_BUSY
I2C_ERR_ADDR_NACK
I2C_ERR_DATA_NACK
I2C_ERR_TIMEOUT
I2C_ERR_ARB_LOST
I2C_ERR_BUS_STUCK
```

### 7.3 BH1750 单次测量流程

`light_read` 每次执行一笔完整的单次测量：

1. 获取共享 I²C mutex；
2. 以独立 I²C 写事务向 `0x23` 写 Power On `0x01`；
3. 再以另一笔独立 I²C 写事务写 One Time H-Resolution `0x20`；BH1750
   的这些 opcode 是完整的一字节指令，不能拼成同一笔连续数据写入；
4. 释放 mutex，使用 RT-Thread 延时等待转换完成，第一版预留约 180 ms；
5. 再次获取 mutex，从 `0x23` 连续读取两个字节；
6. 组合 `raw = (msb << 8) | lsb`；
7. 用整数定点数计算 lux，避免依赖 `printf` 浮点格式化；
8. 打印一次结果并返回。

建议保存 `lux_x100`：

```text
lux_x100 = raw × 250 / 3
```

串口打印时使用 `lux_x100 / 100` 和 `lux_x100 % 100` 生成两位小数。

转换等待期间不应一直占用 I²C mutex，否则会无意义地阻塞 OLED 操作。单次模式下 BH1750 完成后自动进入低功耗状态。

### 7.4 OLED 驱动

第一版 OLED 驱动包含：

- 内部按顺序探测 `0x3C`、`0x3D`；
- SSD1306 128×64 初始化命令表；
- 1024 字节 framebuffer；
- 仅包含显示 `RTThread` 所需的 ASCII 字模，避免引入过大字体库；
- 清屏、设置页/列窗口、刷新 framebuffer；
- display on `0xAF` 和 display off `0xAE`；
- `running` 状态和幂等 start/stop；
- 控制字节 `0x00` 用于命令、`0x40` 用于显示数据。

OLED I²C 设备通常不能可靠读出芯片 ID，所以“地址 ACK”只能证明该地址存在，不能证明它一定是 SSD1306。控制器型号最终仍需通过实物资料或显示效果确认。

为了降低共享总线占用，framebuffer 应按页或小块发送，每一块都有超时；出现错误后立即结束当前刷新并释放 mutex。

## 8. 最终 MSH 命令合同

三条命令均不接收参数。参数数量错误时打印各自的 usage，并返回 `-RT_EINVAL`。

### 8.1 `light_read`

成功示例：

```text
msh />light_read
light_read: addr=0x23 raw=0x04d2 lux=1028.33 status=ok
```

失败示例仍需打印地址、raw、lux 和错误状态：

```text
msh />light_read
light_read: addr=0x23 raw=n/a lux=n/a status=addr_nack
```

约束：

- 每次命令只测量一次，不自动循环；
- 不创建后台采样线程；
- `status` 使用稳定的小写字符串；
- 失败不得打印伪造的 `0 lux`；
- 命令返回值与 `status` 一致，成功为 0，失败为负 RT-Thread 错误码。

### 8.2 `oled_start`

成功示例：

```text
msh />oled_start
oled_start: addr=0x3c controller=ssd1306 state=running status=ok
```

行为：

1. 如果尚未初始化，内部探测 `0x3C/0x3D`；
2. 初始化控制器；
3. 清 framebuffer 和屏幕；
4. 绘制并刷新 `RTThread`；
5. 发送 display on；
6. 设置 `running=true`。

重复执行必须是安全的。若已经运行，可重新刷新一次或直接返回：

```text
oled_start: addr=0x3c controller=ssd1306 state=running status=already_running
```

不得因为 OLED NACK 而禁用整个 I²C 控制器或影响 BH1750。

### 8.3 `oled_stop`

成功示例：

```text
msh />oled_stop
oled_stop: addr=0x3c state=stopped status=ok
```

行为：

1. 禁止驱动后续刷新；
2. 等待当前 OLED I²C 小块事务结束；
3. 发送 display off `0xAE`；
4. 设置 `running=false`；
5. 保留 I²C 控制器使能、mutex 和 BH1750 功能。

若 OLED 已停止，命令应幂等返回 `already_stopped`，而不是报硬错误。`oled_stop` 不要求清除 framebuffer，所以下次 `oled_start` 可以重新初始化并刷新。

### 8.4 MSH 导出

只导出：

```c
MSH_CMD_EXPORT_ALIAS(cmd_light_read, light_read, read BH1750 illuminance once);
MSH_CMD_EXPORT_ALIAS(cmd_oled_start, oled_start, show RTThread on OLED);
MSH_CMD_EXPORT_ALIAS(cmd_oled_stop, oled_stop, stop OLED display);
```

发布前检查 `help`，确认不存在 `lux_loop`、`oled_test`、`oled_addr`、`sensor_demo`、`i2c_scan` 等临时入口。

## 9. 并发、超时与恢复策略

### 9.1 共享总线互斥

mutex 的粒度是一笔 I²C 事务，而不是单个字节。获取锁时使用有限等待，所有 return/goto 错误路径都必须释放锁。

BH1750 的 180 ms 转换等待不持锁；OLED 刷新按页/块持锁，避免一次占用总线过久。

### 9.2 超时层次

至少设置三层超时：

1. RTL 单个 I²C phase 超时；
2. BSP 单条 command/busy 超时；
3. 设备驱动整笔事务超时。

任何一层触发后都返回错误，不允许 shell 永久卡住。总线恢复失败也只影响本次命令，不得触发 SoC 全局复位。

### 9.3 OLED 停止与光照读取的隔离

`oled_stop` 只修改 OLED 状态并向 OLED 地址发送 `0xAE`。它不得：

- 清除 I²C 全局 enable；
- 长时间持有 mutex；
- 对 BH1750 发送任何命令；
- 修改 BH1750 地址或测量模式；
- 复位 SocRV、PS7 FCLK 或 H16 诊断 PLL。

## 10. 与时钟故障诊断的关系

当前 PYNQ-Z2 仍使用 H16→MMCM 时钟链，Kintex-7 使用 200 MHz 差分时钟→MMCM。传感器接入没有修改两块板的时钟或复位链；I²C 控制器也没有把 NACK、timeout 或总线卡低输出接到 `core_rst_n`。

上板时应把设备错误与 SoC 重启分开观察：

- `light_read` 返回 `addr_nack`、`oled_start` 返回 `not_found`，但 RT-Thread 不重启：优先检查设备地址、接线、上拉和 I/O 电压；
- 执行三条命令时 RT-Thread 重启：检查时钟锁定、全局复位、异常寄存器和看门狗，不应仅凭它恰好发生在 I²C 操作期间就归因于传感器；
- Kintex-7 的 `virtual_led[28]` 表示当前 MMCM lock；PYNQ-Z2 当前 LED1 是实时 MMCM lock、LED2 是 FAIL、LED3 是 PASS；
- 此前规划的 PYNQ `FCLK_CLK0` 和 LED2 `lock_loss_sticky` 当前尚未恢复，应在独立时钟任务中实现和验证。

## 11. 验证计划

### 11.1 RTL 单元验证

为 I²C master 建立可控从机模型，覆盖：

- 正常写字节和 ACK；
- 地址 NACK、数据 NACK；
- 正常读两字节，最后一字节主机发送 NACK；
- 重复 START；
- clock stretching；
- SCL/SDA 卡低和 9 脉冲恢复；
- phase timeout；
- 软件复位后总线回到释放状态；
- 任何时候都不主动驱动高电平。

### 11.2 SoC/软件仿真

至少增加：

- MMIO 寄存器访问属性和复位值测试；
- BH1750 原始值到两位小数 lux 的定点换算测试；
- OLED 字模边界和 framebuffer 越界测试；
- MSH 命令参数错误、成功、NACK、timeout 输出测试；
- `help` 中只出现三条最终命令；
- `oled_stop` 后 `light_read` 仍可成功；
- 连续多次 start/stop 不泄漏 mutex 或线程资源。

### 11.3 上板顺序

下列流程必须分别在 PYNQ-Z2 和 Kintex-7 上执行一遍：

1. Kintex-7 先确认 TP5/VADJ1=3.3 V；PYNQ-Z2 确认使用 PMODB 的 3.3 V 电源；
2. 不接模块，确认 SCL/SDA 均释放为高阻，空闲高电平由外部上拉产生；
3. 只接 BH1750，用内部开发探测确认 `0x23` ACK；
4. 执行 `light_read`，与手机照度计或已知光照变化做趋势对比；
5. 断电后接 OLED，内部探测 `0x3C/0x3D`；
6. 执行 `oled_start`，确认清屏并显示 `RTThread`；
7. 执行 `oled_stop`，确认面板关闭；
8. 再执行 `light_read`，确认 OLED 停止不影响 BH1750；
9. 反复执行三条命令至少 100 轮，观察串口、板载状态灯和逻辑分析仪；
10. 拔掉任一模块验证错误能及时返回，RT-Thread 不重启。

## 12. 验收标准

- PYNQ-Z2 的 PMODB W14/Y14 与 Kintex-7 的 J10 F22/G22 均按开漏方式工作，空闲电平与各自 I/O Bank 电压匹配；
- Kintex-7 上板前已确认 TP5/VADJ1 与 XDC 的 `LVCMOS33` 一致；
- I²C 频率在 50 MHz 外设时钟下为约 100 kHz；
- `light_read` 每次只测一次，并固定打印地址、raw、lux、status；
- `oled_start` 显示完整、可辨认的 `RTThread`；
- `oled_stop` 关闭 OLED，之后 `light_read` 仍正常；
- `oled_start`/`oled_stop` 可重复执行且不会死锁；
- 设备缺失、NACK、总线卡住均在有限时间内返回错误；
- 最终 `help` 只新增 `light_read`、`oled_start`、`oled_stop`；
- 传感器错误不改变现有板载状态灯语义，不触发 SocRV 复位；
- 两个 FPGA 目标原有 RT-Thread、UART、CoreMark 和 FPGA 回归继续通过。

## 13. 推荐实施顺序

1. 固化 I2C 地址窗口与寄存器合同；
2. 实现并单测开漏 I²C RTL；
3. 接入 `local_peripheral_subsystem`、SocRV 顶层和 PYNQ-Z2/Kintex-7 两套顶层与 XDC；
4. 更新 JSON 合同并重新生成软件头文件；
5. 实现 `drv_i2c` 与总线 mutex；
6. 实现 BH1750 驱动和 `light_read`；
7. 用内部测试确认 OLED 地址和控制器；
8. 实现 OLED framebuffer、字模、start/stop；
9. 只导出三条最终 MSH 命令；
10. 分别完成 PYNQ-Z2 与 Kintex-7 的综合、实现、时序/DRC 和上板验收。

## 14. 当前结论

PYNQ-Z2 使用 PMODB W14/Y14，Kintex-7 使用 J10 F22/G22；两者都以共享开漏 I²C 连接 BH1750 和 OLED。BH1750 推荐地址为 7-bit `0x23`；OLED 背面的 `0x78/0x7A` 优先按 8-bit 写地址解释，对应内部探测的 7-bit `0x3C/0x3D`。

最终用户接口固定为 `light_read`、`oled_start`、`oled_stop` 三条命令。

截至 2026-08-14，I²C MMIO 合同、开漏主控制器 RTL、PYNQ-Z2 PMODB
引脚、Kintex-7 J10 引脚、BH1750/SSD1306 驱动和上述三条 MSH 命令均已实现。RTL 单元测试、
RTL lint、RT-Thread 固件编译和无外设整机仿真已经通过；无外设时
`light_read` 返回 `addr_nack`，`oled_start` 返回 `not_found`，且不会触发
CPU 异常或 SocRV 复位。PYNQ-Z2 和 Kintex-7 的 Vivado 综合、实现、时序检查，
以及连接真实模块后的光照数值和 OLED 画面仍需按第 11.3 节执行双板上板验收。
