# RT-Thread application resources

| Thread | Priority | Stack | Time slice | Purpose |
| --- | ---: | ---: | ---: | --- |
| `main` | 10 | 2048 bytes | 10 ticks | RT-Thread user entry |
| `worker` | 25 | 1024 bytes | 10 ticks | scheduler/tick smoke and PASS owner |
| `tshell` | 20 | 2048 bytes | default | FinSH/MSH polling console |
| `tidle0` | 31 | 512 bytes | default | RT-Thread idle |

The CoreMark RT-Thread profile reuses the main thread and a 2 KiB static
benchmark data area.  It does not place the CoreMark data block on a thread
stack.

The FPGA `rtthread-coremark` image registers these MSH commands:
`help`, `ps`, `free`, `version`, `list`, `clear`, `uptime`, `socrv_info`, and
`coremark`. Run `make sim-msh` to verify the help table, thread listing, and
uptime output through the real UART path before programming the board.
