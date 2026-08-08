# The MMIO bridge and interrupt synchronizers deliberately isolate these clock
# domains.  The bundled payload is held stable across the full toggle handshake
# and every receiving register is ASYNC_REG-marked.
set_clock_groups -asynchronous \
  -group [get_clocks clk_core_unbuffered] \
  -group [get_clocks clk_periph_unbuffered]
