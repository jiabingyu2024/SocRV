# RT-Thread application resources

| Thread | Priority | Stack | Time slice | Purpose |
| --- | ---: | ---: | ---: | --- |
| `main` | 10 | 2048 bytes | 10 ticks | RT-Thread user entry |
| `worker` | 25 | 1024 bytes | 10 ticks | scheduler/tick smoke and PASS owner |
| `tshell` | 20 | 2048 bytes | default | FinSH/MSH polling console |
| `tempmon` | 22 | 1536 bytes | 10 ticks | SHT30 background temperature monitor |
| `tidle0` | 31 | 512 bytes | default | RT-Thread idle |

The CoreMark RT-Thread profile reuses the main thread and a 2 KiB static
benchmark data area.  It does not place the CoreMark data block on a thread
stack.

`tempmon` is created during component initialization and sleeps on a semaphore
until `temp_start` is entered. `temp_stop` wakes it immediately and returns it
to the stopped state without blocking the FinSH thread.
