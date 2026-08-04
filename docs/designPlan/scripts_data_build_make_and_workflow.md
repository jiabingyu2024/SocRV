# 工程构建入口与操作流程

> 适用项目：`SocRV` 的 RTL、TB/Sim、Software、FPGA 和 Release 自动化。  
> 本文把 `scripts/`、`data/`、`build/` 与仓库根目录 `Makefile` 接成一条统一流程，规定输入、编排、产物、命令行和操作顺序。  
> 各侧内部技术细节仍由 RTL、TB/Sim、FPGA 和 Software 专项文档负责；本文只定义跨目录合同和总入口。

---

## 0. 总体思路

一次可重复操作分成四层：

```text
Make
    给开发者稳定、易记的顶层入口
            ↓
Scripts
    解析参数、检查环境、调用工具、管理结果
            ↓
Data / Source Manifests
    提供受控输入、Profile、测试清单和板卡事实
            ↓
Build
    保存本次构建和运行产生的全部可删除产物
```

核心边界：

```text
Makefile 不承载复杂业务逻辑
scripts/ 不保存运行产物
data/ 不接收临时生成文件
build/ 不成为设计输入的唯一来源
```

顶层操作形成统一链路：

```text
environment
→ check
→ software
→ image
→ RTL/TB build
→ simulation/regression
→ FPGA build
→ board test
→ report
→ release
```

---

## 1. 推荐目录

```text
SocRV/
├─ Makefile
├─ README.md
│
├─ scripts/
│  ├─ README.md
│  ├─ lib/
│  │  ├─ repo.py
│  │  ├─ command.py
│  │  ├─ manifest.py
│  │  ├─ hashing.py
│  │  ├─ logging_utils.py
│  │  └─ result_schema.py
│  ├─ check_environment.py
│  ├─ check_filelists.py
│  ├─ check_memory_map.py
│  ├─ check_images.py
│  ├─ check_generated_tree.py
│  ├─ build_software.py
│  ├─ inspect_elf.py
│  ├─ elf2mem.py
│  ├─ run_verilator.py
│  ├─ run_xsim.py
│  ├─ run_regression.py
│  ├─ run_vivado.py
│  ├─ program_board.py
│  ├─ check_fpga_reports.py
│  ├─ collect_reports.py
│  ├─ package_release.py
│  └─ verify_release.py
│
├─ data/
│  ├─ README.md
│  ├─ schemas/
│  │  ├─ board.schema.json
│  │  ├─ profile.schema.json
│  │  ├─ image.schema.json
│  │  ├─ testlist.schema.json
│  │  └─ result.schema.json
│  ├─ profiles/
│  │  ├─ smoke.yaml
│  │  ├─ rtthread.yaml
│  │  └─ coremark.yaml
│  ├─ images/
│  ├─ isa/
│  ├─ tests/
│  ├─ expected/
│  └─ reference/
│
├─ build/
│  ├─ manifest/
│  ├─ software/
│  ├─ image/
│  ├─ verilator/
│  ├─ xsim/
│  ├─ vivado/
│  ├─ log/
│  ├─ result/
│  ├─ wave/
│  ├─ report/
│  └─ release/
│
└─ docs/designPlan/
```

常用入口保持在 `scripts/` 根目录，与总项目结构一致。公共 Python 实现放 `scripts/lib/`；以后脚本数量显著增加时可以内部重组，但根 Make 调用的入口名保持稳定。

---

## 2. 四类内容的定义

### 2.1 Source

手写、受版本控制的设计内容：

```text
rtl/
tb/
software/
fpga/
sim/
scripts/
docs/
```

### 2.2 Controlled Data

不是程序逻辑，但会改变构建或测试结果的受控输入：

```text
Board facts
Profile
Testlist
Expected result
ISA test input
Reference data
Schema
```

放在 `data/` 或相应 Owner 目录。

### 2.3 Generated Artifact

由工具产生、可从 Source 和 Controlled Data 重建：

```text
ELF/MAP/DIS
MEM/HEX/COE
Verilator obj_dir
仿真可执行文件
Vivado project/runs/cache
DCP/bitstream
log/result/wave/report
release staging
```

统一进入 `build/`。

### 2.4 External Dependency

第三方源码和工具：

```text
RT-Thread upstream
CoreMark upstream
DiffTest upstream
RISC-V ISA tests
toolchain
Vivado
Verilator
```

必须固定版本或记录版本，不把本机缓存路径当仓库事实。

---

## 3. `scripts/` 的职责

脚本负责：

- 从任意当前目录定位 repo root；
- 读取并验证 manifest；
- 解析 Board/Profile/Test；
- 发现工具并检查版本；
- 创建目标专用 build 目录；
- 组装安全、可打印的命令参数；
- 调用编译器、Verilator、Vivado 等工具；
- 保存完整 log；
- 检查退出码和关键产物；
- 写结构化 result/manifest；
- 打印复现命令；
- 向 Make 返回可靠状态。

脚本不负责：

- 定义 RTL 功能；
- 重写 Memory Map；
- 在失败后自动改源码；
- 把本机绝对路径写回受控 Data；
- 静默接受缺失结果；
- 用日志字符串代替所有正式状态。

---

## 4. 公共脚本库

### 4.1 `repo.py`

提供：

```text
repo_root()
resolve_repo_path()
ensure_inside_repo()
build_path()
```

所有脚本使用同一套路径规则，不各自通过 `../../..` 猜根目录。

### 4.2 `command.py`

统一：

- 参数数组调用；
- 工作目录；
- 环境变量增量；
- stdout/stderr 合并或分流；
- log；
- timeout；
- 返回码；
- 可复制命令显示。

不通过拼接 shell 字符串传递不可信路径。

### 4.3 `manifest.py`

统一读取：

```text
YAML
JSON
schema_version
schema validation
default handling
unknown field check
```

未知字段默认报错或警告，防止拼写错误被静默忽略。

### 4.4 `hashing.py`

用于：

- filelist 内容；
- 源文件集合；
- flags；
-工具版本；
- Profile；
- ELF/image；
- bitstream。

Hash 用于追踪和缓存判断，不用时间戳冒充完整依赖关系。

### 4.5 `result_schema.py`

统一状态：

```text
PASS
FAIL
TIMEOUT
ASSERTION
DIFF_MISMATCH
BUILD_ERROR
CONFIG_ERROR
CRASH
NO_RESULT
UNSUPPORTED
```

各 Runner 不自行发明相近但不同的状态字符串。

---

## 5. 脚本命令行规范

所有脚本至少支持：

```text
--help
--verbose
```

涉及目标选择时统一：

```text
--board
--profile
--target
--test
--jobs
```

运行型脚本统一：

```text
--seed
--max-cycles
--trace
--result
--log
```

### 5.1 默认值

默认值来源优先级：

```text
显式命令行
→ 顶层 Make 传入
→ Profile
→ 项目默认
```

环境变量只用于工具路径、许可证或 CI 环境，不作为大量功能参数的隐形配置。

### 5.2 Dry Run

复杂构建脚本可支持：

```text
--dry-run
```

显示将读取的 manifest、目标目录和外部命令，不创建最终产物。

### 5.3 错误信息

配置错误要指出：

```text
文件
字段
实际值
允许值
修复方向
```

工具失败要指出 log 和复现命令。

---

## 6. `data/` 的职责

`data/` 保存长期受控输入，不保存某次运行结果。

允许：

- Profile；
- Schema；
- ISA 测试输入；
- 测试 stimulus；
- golden/reference；
- 固定的外部数据集；
- 需要提交的预构建初始化镜像及来源说明。

Board Facts 也属于 Controlled Data，但按模块 Owner 放在：

```text
fpga/boards/<board>/board.yaml
```

不在 `data/boards/` 维护第二份。

不允许：

- 自动生成的普通 ELF；
- 当前机器的绝对路径；
- Verilator 波形；
- Vivado report；
- 临时日志；
- 未说明来源的二进制；
- 可以从当前软件源码稳定生成却没有 manifest 的镜像副本。

---

## 7. Board Data

`fpga/boards/<board>/board.yaml` 记录结构化 Board Facts：

```yaml
schema_version: 1
name: kintex7_competition
vendor: xilinx
part: <待冻结>
top: fpga_top
clock:
  port: <待冻结>
  frequency_hz: <待冻结>
reset:
  port: <待冻结>
  active: <待冻结>
constraints:
  - fpga/boards/kintex7_competition/constraints/pins.xdc
  - fpga/boards/kintex7_competition/constraints/clocks.xdc
```

具体值冻结后必须填写，规划阶段允许显式列入开放问题，不允许让构建使用 `<待冻结>`。

### 7.1 Board Data 与 Board README

```text
YAML
    给脚本读取的结构化事实

README
    给开发者阅读的接线、工具和操作说明
```

两者内容有重叠时，以评审后的结构化值为构建输入。

---

## 8. Profile Data

Profile 跨越多个子系统，描述“这次要构建什么”：

```yaml
schema_version: 1
name: rtthread
software:
  profile: rtthread
image:
  format: split_code_data
simulation:
  target: soc
  default_test: rtthread
fpga:
  board: kintex7_competition
  debug: false
```

Profile 可以引用各侧更细的配置，但不复制大量事实。

### 8.1 Profile 不拥有的内容

以下仍由专项 Owner 管理：

```text
Memory Map       RTL/架构合同
pin              Board/XDC
Test expectation sim/regression
compiler flags   Software Profile/toolchain
Vivado strategy  FPGA Tcl/Profile
```

顶层 Profile 只选择，不重定义。

Profile 分层：

```text
data/profiles/
    跨 Software/Sim/FPGA 的系统级选择

software/profiles/
    编译源、入口、ISA/ABI 和链接配置

fpga/profiles/
    FPGA Backend、Debug 和实现配置
```

系统级 Profile 通过名称引用后两者，不复制其字段。

### 8.2 Profile 组合

第一阶段推荐显式 Profile 文件，暂不引入复杂继承。需要复用时只允许一层：

```text
base: smoke
overrides:
  software: rtthread
```

脚本输出展开后的 Effective Profile 到 `build/manifest/`。

---

## 9. Test Data 与 Expected Data

### 9.1 Test Data

保存：

- ISA test image/source reference；
- UART 输入脚本；
- GPIO 事件；
- Memory Model stimulus；
- 固定随机 seed 集；
- 测试使用的固定输入数据。

正式测试定义仍由：

```text
sim/regression/testlist.yaml
```

管理；`data/tests/` 只保存其中引用的 stimulus。

### 9.2 Expected Data

保存：

- Golden CRC；
- 明确的 UART 片段；
- Memory signature；
- 性能基线；
- 已批准的预期失败。

状态预期和已批准预期失败由：

```text
sim/regression/expected_results.yaml
```

管理；`data/expected/` 保存较大的 Golden payload 或 reference 文件。

### 9.3 Expected 不是日志快照

把一次输出整段复制成 Golden 前必须确认：

- 哪些字段稳定；
- 哪些地址/时间/计数会变化；
- 比较粒度；
- 更新原因；
- Owner。

预期数据更新要像源码修改一样评审。

---

## 10. Schema 与版本

每种跨脚本文件包含：

```text
schema_version
```

至少维护：

```text
profile
board
image
testlist
result
release
```

脚本行为：

```text
支持版本 → 读取
未知新版本 → 明确失败
旧版本可迁移 → 输出迁移提示
缺少版本 → 仅在早期兼容期警告
```

Schema 放 `data/schemas/`，示例文件通过验证测试。

---

## 11. `build/` 的职责

`build/` 是统一生成物根目录：

```text
build/
├─ manifest/
├─ software/
├─ image/
├─ verilator/
├─ xsim/
├─ vivado/
├─ log/
├─ result/
├─ wave/
├─ report/
└─ release/
```

任何工具默认不在仓库根目录生成：

```text
vivado.log/jou
xsim.log
obj_dir
*.wdb
*.fst
*.bit
firmware.elf
```

脚本为每个工具设置明确工作目录和输出路径。

---

## 12. Build 命名

### 12.1 Software

```text
build/software/<software-profile>/
build/image/<software-profile>/
```

### 12.2 Verilator

```text
build/verilator/unit/<unit>/
build/verilator/cpu/
build/verilator/soc/
```

运行结果：

```text
build/log/<target>/<test>.log
build/result/<target>/<test>.json
build/wave/<target>/<test>.fst
```

### 12.3 Vivado

```text
build/vivado/<board>/<profile>/
```

### 12.4 Release

```text
build/release/<release-name>/
```

Release staging 可以删除重建；正式归档由显式命令完成。

---

## 13. Build Manifest

每个主要目标写：

```json
{
  "schema_version": 1,
  "kind": "verilator_build",
  "target": "soc",
  "git_commit": "...",
  "git_dirty": false,
  "tool": {
    "name": "verilator",
    "version": "..."
  },
  "inputs": {
    "filelist_hash": "...",
    "flags_hash": "...",
    "source_hash": "..."
  },
  "outputs": {
    "binary": "build/verilator/soc/sim_soc"
  }
}
```

Software、Image、FPGA 使用相同思路。

### 13.1 Dirty 状态

本地 Debug 允许 dirty build，但 manifest 必须记录。正式 Release 默认拒绝 dirty tree，除非显式使用受审查的 override。

### 13.2 原子写入

Result/Manifest 先写临时文件，完成并校验后原子替换目标。进程中断不应留下看似完整的半截 JSON。

---

## 14. 缓存与增量构建

复用旧产物前比较：

```text
工具版本
Top
Filelist
源文件 hash
flags
Profile
生成脚本版本
外部依赖版本
```

### 14.1 不能只看时间戳

跨机器、解压、Git checkout 会改变时间戳语义。时间戳可用于快速候选判断，最终缓存身份由 manifest/hash 确认。

### 14.2 增量失败回退

如果 manifest 缺失、损坏或版本未知：

```text
拒绝复用
→ 重建该目标
```

不删除其他 Board/Profile 的无关目录。

---

## 15. 根目录 Makefile 的职责

Makefile 提供稳定入口：

```text
帮助
变量默认值
目标依赖关系
调用脚本
传递退出码
```

Makefile 不实现：

- YAML/JSON 解析；
- ELF segment 拆分；
- Vivado 报告解析；
- 测试结果判断；
- 复杂文件 hash；
- 大量 Shell 分支。

### 15.1 推荐变量

```make
BOARD   ?= kintex7_competition
PROFILE ?= smoke
TARGET  ?= soc
TEST    ?=
SEED    ?= 1
TRACE   ?= 0
JOBS    ?= 4
```

默认值必须在 `make help` 展示。

### 15.2 变量传递

Make 传成显式脚本参数：

```text
$(PYTHON) scripts/run_verilator.py \
    run \
    --target "$(TARGET)" \
    --profile "$(PROFILE)" \
    --test "$(TEST)" \
    --seed "$(SEED)"
```

脚本仍负责类型、枚举和路径验证。

---

## 16. 推荐 Make 入口

### 帮助和环境

```text
make help
make env-check
make doctor
```

### 静态检查

```text
make check
make check-filelists
make check-memory-map
make lint
make lint-core
make lint-soc
make lint-tb
```

### Software/Image

```text
make software PROFILE=hello
make software PROFILE=rtthread
make image PROFILE=rtthread
make software-size PROFILE=rtthread
make software-disasm PROFILE=rtthread
```

### Unit/CPU/SoC Simulation

```text
make sim-unit TEST=hxi
make sim-isa TEST=rv32ui-p-add
make sim-isa-all
make sim-soc TEST=timer_irq
make sim-soc TEST=rtthread TRACE=1
```

### Regression

```text
make regression SUITE=smoke
make regression SUITE=unit
make regression SUITE=isa
make regression SUITE=soc
make regression SUITE=nightly
```

### FPGA

```text
make fpga-elab BOARD=kintex7_competition PROFILE=smoke
make fpga-synth BOARD=kintex7_competition PROFILE=rtthread
make fpga-impl BOARD=kintex7_competition PROFILE=rtthread
make fpga-bitstream BOARD=kintex7_competition PROFILE=rtthread
make fpga-build BOARD=kintex7_competition PROFILE=rtthread
make fpga-program BOARD=kintex7_competition PROFILE=rtthread
make fpga-report BOARD=kintex7_competition PROFILE=rtthread
```

`fpga-build` 是到 bitstream 的总入口；`fpga-synth`、`fpga-impl` 和 `fpga-bitstream` 用于分阶段执行与排错。

### Release

```text
make release-check PROFILE=rtthread
make release PROFILE=rtthread
make release-verify PROFILE=rtthread
```

### 清理

```text
make clean-sim
make clean-software
make clean-fpga BOARD=... PROFILE=...
make clean-profile PROFILE=...
make clean-all
```

`clean-all` 必须显式限制在仓库的 `build/`，文档提示其影响。普通开发优先使用有范围的 clean。

---

## 17. Make 目标依赖

推荐：

```text
check
├─ check-filelists
├─ check-memory-map
└─ validate-data

image
└─ software

sim-isa
├─ check
└─ 对应测试 image

sim-soc
├─ check
└─ image

regression
├─ check
├─ 必要 build targets
└─ run_regression

fpga-elab
├─ check
├─ image
└─ FPGA source/IP check

fpga-bitstream
├─ fpga-impl
└─ report gate

release
├─ release-check
├─ regression smoke
├─ fpga-bitstream
└─ package_release
```

不要让每个目标无条件重复执行完整回归；依赖负责必要前置，严格发布测试由 Release Gate 明确调用。

---

## 18. Make Target 设计规则

### 18.1 `.PHONY`

命令入口声明 `.PHONY`：

```make
.PHONY: help check software image sim-isa sim-soc regression
```

避免同名文件让目标失效。

### 18.2 安静与可见

普通模式打印：

```text
阶段
目标
Profile
关键产物
最终状态
```

详细外部命令进入 log；`VERBOSE=1` 时完整显示。

### 18.3 Help

`make help` 自动或显式列出：

- 目标；
- 说明；
- 常用变量；
- 默认值；
- 示例；
- 产物位置。

### 18.4 失败传播

脚本非零时 Make 目标立即失败。禁止：

```text
command || true
忽略 Vivado/Verilator 返回码
生成空结果后继续打包
```

---

## 19. 环境检查

`make env-check` 检查：

```text
Python 版本
Python package
Verilator
C++ compiler
RISC-V GCC/binutils
Make
Vivado（FPGA 目标需要）
Git/submodule
可选 Java/SBT 等 DiffTest 依赖
```

输出：

```text
FOUND / MISSING / VERSION_MISMATCH / OPTIONAL
```

### 19.1 分目标检查

基础 Sim 不应因为本机没有 Vivado 而失败：

```text
env-check-base
env-check-sim
env-check-software
env-check-fpga
env-check-difftest
```

`doctor` 可运行全部并给出安装提示。

### 19.2 Tool Override

允许：

```text
VERILATOR
RISCV_GCC_PREFIX
VIVADO
PYTHON
```

实际解析路径和版本写入 build manifest。

---

## 20. 操作流程：首次拉取

```text
git clone / checkout
→ 初始化受控 submodule
→ make env-check
→ make check
→ make software PROFILE=hello
→ make image PROFILE=hello
→ make sim-soc TEST=hello
```

验收：

- 环境报告清楚；
- Filelist/Memory Map 检查通过；
- ELF 和 image 生成；
- SoC Smoke PASS；
- log/result 路径可找到。

首次流程不要求安装 Vivado 才能完成软件与 Verilator Smoke。

---

## 21. 操作流程：日常 RTL 开发

### CPU 修改

```text
make lint-core
→ make sim-isa TEST=<directed>
→ make regression SUITE=isa-smoke
→ make sim-soc TEST=smoke
```

### HXI/Memory 修改

```text
make sim-unit TEST=hxi
→ make sim-unit TEST=memory
→ make sim-isa TEST=load_store
→ make sim-soc TEST=memory_smoke
```

### Peripheral/IRQ 修改

```text
make sim-unit TEST=<peripheral>
→ make sim-soc TEST=<baremetal>
→ make sim-soc TEST=rtthread
```

需要波形时只对失败单测：

```text
make sim-soc TEST=<test> TRACE=1
```

---

## 22. 操作流程：Software 开发

```text
make software PROFILE=<profile>
→ 检查 ELF/MAP/size
→ make image PROFILE=<profile>
→ make sim-soc TEST=<test>
→ 检查 UART/Test Status
```

RT-Thread：

```text
make software PROFILE=rtthread
→ make image PROFILE=rtthread
→ make sim-soc TEST=rtthread
→ make regression SUITE=os-smoke
```

CoreMark：

```text
make software PROFILE=coremark
→ make image PROFILE=coremark
→ make sim-soc TEST=coremark-smoke
→ FPGA 正式构建和运行
```

---

## 23. 操作流程：回归

```text
make regression SUITE=smoke JOBS=<n>
```

Runner：

```text
读取 testlist
→ 展开测试
→ 校验 image/profile
→ 按目标构建或复用 binary
→ 并行启动测试
→ 每测写 JSON/log
→ 写 summary.json
→ 返回总状态
```

### 23.1 回归产物

```text
build/result/regression/<suite>/summary.json
build/report/regression/<suite>/summary.md
build/log/<target>/<test>.log
```

Summary 包含：

```text
PASS/FAIL/TIMEOUT/UNSUPPORTED 数量
失败测试
seed
运行时间
复现命令
Git/工具版本
```

### 23.2 失败复现

报告给出：

```text
make sim-soc TEST=<name> SEED=<seed> TRACE=1
```

不要求开发者从 CI 命令行手工反推参数。

---

## 24. 操作流程：FPGA

```text
make env-check-fpga
→ make check
→ make image PROFILE=<profile>
→ make fpga-elab BOARD=<board> PROFILE=<profile>
→ make fpga-synth ...
→ make fpga-impl ...
→ make fpga-report ...
→ make fpga-bitstream ...
→ make fpga-program ...
→ board smoke
```

在 bitstream 前检查：

```text
timing
DRC
CDC
blackbox
软件镜像 hash
```

Board Smoke 结果进入：

```text
build/result/fpga/<board>/<profile>/
```

---

## 25. 操作流程：Release

```text
确认 clean Git 或批准 override
→ make env-check
→ make check
→ make regression SUITE=release
→ make software/image
→ make fpga-bitstream
→ board smoke
→ make release-check
→ make release
→ make release-verify
```

Release 包含：

```text
source identity
software ELF/MAP
image manifest
bitstream
FPGA reports
simulation summary
board result
tool versions
known limitations
checksums
```

### 25.1 Release Name

建议：

```text
SocRV-<version>-<board>-<profile>-<commit>
```

不要只用 `final.zip`、`new.bit`。

### 25.2 Verify

在新临时目录解包，检查：

- manifest；
- checksums；
- 必要文件；
- bitstream/ELF 对应关系；
- 报告 Gate；
- 可选快速 Smoke。

---

## 26. 日志与结果

### 26.1 Log

所有外部命令保存完整 log：

```text
build/log/software/<profile>.log
build/log/cpu/<test>.log
build/log/soc/<test>.log
build/log/fpga/<board>/<profile>/<stage>.log
```

### 26.2 Result

运行和 Gate 写 JSON：

```text
build/result/<domain>/...
```

Result 字段统一：

```text
schema_version
kind
status
target
profile/test
start/end/duration
git
tool versions
inputs
outputs
failure
reproduce
```

### 26.3 Report

Report 是人类可读汇总：

```text
Markdown
Text
Vivado rpt
HTML（可选）
```

Result JSON 是自动化判断来源，Report 不能替代机器状态。

---

## 27. 安全清理

清理脚本只允许删除解析后的：

```text
<repo>/build/...
```

执行前检查：

- repo root；
- 目标位于 build；
- Board/Profile 名已验证；
- 不是空路径；
- 不是仓库根；
- 不跟随意外 symlink/junction 到仓库外。

### 27.1 Scoped Clean

优先：

```text
clean-software PROFILE=x
clean-sim TARGET=soc
clean-fpga BOARD=x PROFILE=y
```

`clean-all` 显示目标绝对路径并删除整个 `build/`，不碰 `data/` 和源码。

### 27.2 Clobber

若需要连外部依赖缓存一起删除，使用独立：

```text
make clobber
```

并要求显式确认/参数。普通 `clean` 不承担该行为。

---

## 28. 可重复性

每次运行记录：

```text
Git commit/dirty
submodule commit
OS
工具版本
命令
Board/Profile/Test
seed
flags
source/manifest hash
输入 image hash
```

随机测试：

```text
默认固定 seed
多 seed 由回归显式展开
失败保存复现 seed
```

绝对路径可以出现在本地 log，不进入受控 manifest 的可移植字段。

---

## 29. CI 与本地统一

CI 调用与开发者相同的 Make 目标：

```text
make check
make regression SUITE=smoke
make fpga-synth ...
```

CI YAML 只负责：

- 准备环境；
- 缓存；
- 调用 Make；
- 上传 `build/` 中选定产物。

不在 CI YAML 维护另一套 Verilator/Vivado 命令。

### 29.1 CI Gate

建议：

```text
PR fast
    check + lint + smoke

main
    ISA/SOC regression

nightly
    stress + multi-seed + long RT-Thread

release
    full regression + FPGA + board result
```

---

## 30. 旧工程资产的迁移

上一轮可参考：

| 旧资产 | 保留机制 | 新 Owner |
| --- | --- | --- |
| 根 `Makefile` | 易记目标与变量入口 | 新根 Makefile |
| `scripts/run_verilator.py` | build/run、log/result/wave | 新 `scripts/run_verilator.py` |
| `scripts/run_difftest.py` | 独立 DiffTest 编排 | 统一 Runner/薄入口 |
| `scripts/prepare_test_data.py` | 受控测试输入准备 | 新 `scripts/prepare_test_data.py` 或相应统一入口 |
| `scripts/filelists/` | 层级化 Filelist | `sim/filelists/` |
| `build/log/` | 每测日志 | 新 `build/log/` |
| `build/result/` | JSON 结果 | 新统一 Result Schema |
| timing path 脚本 | 报告后处理 | `scripts/collect_reports.py` 或 FPGA 专用入口 |

不迁移：

- 根目录 Vivado/XSim 临时日志；
- 旧 Top 名；
- 写死旧路径的参数；
- 旧 Memory Map/Profile；
- 多脚本各自维护的重复状态定义；
- 仅凭文件存在判断缓存有效。

---

## 31. 推荐实施顺序

### 第一阶段：稳定总入口

建立：

```text
make help
make env-check
make check
```

### 第二阶段：Software/Image

接通：

```text
make software
make image
```

生成 ELF、image 和 manifest。

### 第三阶段：CPU/SoC Sim

接通：

```text
make sim-isa
make sim-soc
```

统一 JSON、log、退出码和失败复现命令。

### 第四阶段：Regression

引入 Testlist、Suite、并行调度和 Summary。

### 第五阶段：FPGA

接通 elaboration、synthesis、implementation、reports、bitstream、program。

### 第六阶段：Schema/Hash

冻结 Board/Profile/Image/Result Schema 和增量构建判断。

### 第七阶段：Release

接通 Gate、打包、checksums 和解包验证。

### 第八阶段：CI

CI 只调用稳定 Make 目标并上传规定产物。

---

## 32. 开放问题

1. Python 最低版本和依赖管理方式；
2. YAML 库和 Schema 验证库；
3. 根 Make 是否支持 Windows 原生环境或统一在 WSL/Linux；
4. Vivado 调用环境；
5. RISC-V 工具链发现方式；
6. Board/Profile/Test schema；
7. `data/isa` 是源码、预构建镜像还是外部依赖；
8. 大体积 Data 是否使用 Git LFS；
9. DiffTest 外部生成物位置；
10. Build hash 的性能与粒度；
11. CI 缓存键；
12. Release Gate 和版本命名；
13. Board 自动化结果如何采集；
14. `clean-all` 的交互策略。

暂定建议：

```text
Make：
    只做稳定入口和依赖

Scripts：
    Python 负责编排，Tcl 负责 Vivado 内部阶段

Data：
    只放受控输入和 schema

Build：
    所有生成物统一进入，按 target/profile 隔离

Manifest：
    记录工具、源、flags、输入和产物 hash

Result：
    统一状态与 schema

Operation：
    软件/Sim 不依赖 Vivado；FPGA 目标单独检查环境

Release：
    由 Gate 后的受控产物打包
```

---

## 33. 验收标准

### Scripts

- [ ] 所有脚本可从任意当前目录定位仓库；
- [ ] 公共路径、命令、manifest 和结果逻辑不重复；
- [ ] 外部命令使用参数数组并保存 log；
- [ ] 失败返回可靠非零状态；
- [ ] 缺失或损坏结果不判 PASS；
- [ ] 每个失败给出复现命令；
- [ ] 脚本不修改受控 Data。

### Data

- [ ] Board/Profile/Test/Image/Result 有 schema_version；
- [ ] Data 只保存受控输入；
- [ ] 二进制数据有来源和 hash；
- [ ] Expected 更新可审查；
- [ ] 没有本机绝对路径；
- [ ] Profile 不重复定义 Memory Map 和 pin。

### Build

- [ ] 所有生成物进入 `build/`；
- [ ] Software/Sim/FPGA/Profile 目录隔离；
- [ ] 主要目标有 manifest；
- [ ] 缓存比较工具、源、flags 和 Profile；
- [ ] Result 原子写入；
- [ ] 删除 `build/` 后可完整重建；
- [ ] Scoped Clean 不影响其他目标和源码。

### Make

- [ ] `make help` 完整；
- [ ] 常用变量和默认值统一；
- [ ] Make 不解析复杂 YAML/JSON；
- [ ] Software/Image/Sim/Regression/FPGA/Release 有稳定入口；
- [ ] 失败状态完整传播；
- [ ] CI 与本地调用相同目标；
- [ ] `clean-all` 仅作用于 `build/`。

### 操作流程

- [ ] 首次拉取可按文档跑通 SoC Smoke；
- [ ] RTL 修改有对应短回归；
- [ ] Software 能生成同一 Sim/FPGA 镜像；
- [ ] 回归有 Summary 和复现命令；
- [ ] FPGA 在 bitstream 前经过报告 Gate；
- [ ] Release 可解包校验；
- [ ] Git、工具、Profile、seed 和产物 hash 可追踪。

---

## 34. 各层一句话边界

```text
Make：
    给人一个稳定入口

scripts：
    把多个工具和合同编排成可靠执行

data：
    保存会影响结果的受控非源码输入

build：
    保存本次执行产生的可删除内容

manifest：
    说明这份产物由什么生成

result：
    说明这次运行是否成功以及为什么

report：
    把机器结果整理成人可读信息

profile：
    选择这次构建使用的软件、仿真和 FPGA 配置

schema：
    保证脚本间交换文件可验证、可演进

release：
    汇集通过 Gate、能够追踪的最终交付物
```

整个工程优先冻结：

```text
Make 目标和变量
+ Profile/Board/Test Schema
+ Build 目录与 Manifest
+ Result 状态
+ Software/Image 合同
+ Sim/FPGA Runner 退出码
+ 回归与 Release Gate
```
