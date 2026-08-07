// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// SocRV integration note:
// All software-visible MMIO addresses are classified as uncached memory and
// reach the existing SocRV peripherals through the DCache/HXI path.  Keep the
// legacy RSD-local timer/serial interface quiescent so there is only one timer,
// one UART and one authoritative address map in the complete SoC.

`include "BasicMacros.sv"

import BasicTypes::*;
import IO_UnitTypes::*;

module IO_Unit(
    IO_UnitIF.IO_Unit port,
    CSR_UnitIF.IO_Unit csrUnit
);
    always_comb begin
        port.ioReadDataOut = '0;
        port.serialWE = FALSE;
        port.serialWriteDataOut =
            port.ioWriteDataIn[SERIAL_OUTPUT_WIDTH-1:0];
    end

    logic unused;
    assign unused = port.ioWE ^ ^port.ioReadAddrIn ^
                    ^port.ioWriteAddrIn ^ csrUnit.reqTimerInterrupt;
endmodule
