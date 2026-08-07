// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0.
// SocRV integration: retain full logical addresses and use the SoC map.

package MemoryMapTypes;

import BasicTypes::*;

localparam INSN_RESET_VECTOR = 32'h0000_0000;
localparam PC_GOAL = memory_map_pkg::TEST_STATUS_BASE;

// SocRV has disjoint CODE, DATA and MMIO regions.  RSD's original narrow-PC
// encoding assumed ROM at 0x0000_1000 and RAM at 0x8000_0000, so it cannot be
// used here without aliasing valid SocRV addresses.
localparam PC_WIDTH = ADDR_WIDTH;
localparam PC_TAG = 0;
typedef logic [PC_WIDTH-1:0] PC_Path;

function automatic AddrPath ToAddrFromPC(input PC_Path pc);
    return pc;
endfunction

function automatic PC_Path ToPC_FromAddr(input AddrPath addr);
    return addr;
endfunction

typedef enum logic [1:0] {
    MMT_MEMORY  = 2'b00,
    MMT_IO      = 2'b01,
    MMT_ILLEGAL = 2'b10
} MemoryMapType;

// Keep the complete SocRV byte address at the RSD cache boundary.  The two
// flag bits remain separate because the RSD caches use isUncachable as part of
// their ordering contract.  SocRV MMIO is deliberately presented as uncached
// memory (not RSD-internal IO) so accesses reach the existing HXI peripherals.
localparam PHY_RAW_ADDR_WIDTH = ADDR_WIDTH;
localparam PHY_ADDR_WIDTH = PHY_RAW_ADDR_WIDTH + 2;
localparam PHY_ADDR_WIDTH_BIT_SIZE = $clog2(PHY_ADDR_WIDTH);
localparam PHY_ADDR_BYTE_WIDTH = PHY_ADDR_WIDTH / BYTE_WIDTH;
localparam PHY_RAW_ADDR_WIDTH_BIT_SIZE = $clog2(PHY_RAW_ADDR_WIDTH);
localparam PHY_RAW_ADDR_BYTE_WIDTH = PHY_RAW_ADDR_WIDTH / BYTE_WIDTH;

typedef logic [PHY_RAW_ADDR_WIDTH-1:0] PhyRawAddrPath;
typedef struct packed {
    logic isUncachable;
    logic isIO;
    PhyRawAddrPath addr;
} PhyAddrPath;

function automatic logic InRegion(
    input AddrPath addr,
    input logic [31:0] base,
    input logic [31:0] size
);
    return addr >= base && addr < (base + size);
endfunction

function automatic logic IsCodeAddress(input AddrPath addr);
    return InRegion(addr, memory_map_pkg::CODE_BASE,
                    memory_map_pkg::CODE_SIZE);
endfunction

function automatic logic IsDataAddress(input AddrPath addr);
    return InRegion(addr, memory_map_pkg::DATA_BASE,
                    memory_map_pkg::DATA_SIZE);
endfunction

function automatic logic IsMMIOAddress(input AddrPath addr);
    return InRegion(addr, memory_map_pkg::TIMER_BASE,
                    memory_map_pkg::TIMER_SIZE) ||
           InRegion(addr, memory_map_pkg::IRQ_CTRL_BASE,
                    memory_map_pkg::IRQ_CTRL_SIZE) ||
           InRegion(addr, memory_map_pkg::APB_BASE,
                    memory_map_pkg::APB_SIZE);
endfunction

function automatic MemoryMapType GetMemoryMapType(input AddrPath addr);
    if (IsCodeAddress(addr) || IsDataAddress(addr) || IsMMIOAddress(addr))
        return MMT_MEMORY;
    return MMT_ILLEGAL;
endfunction

function automatic PhyAddrPath ToPhyAddrFromLogical(input AddrPath logAddr);
    PhyAddrPath phyAddr;
    phyAddr.addr = logAddr;
    phyAddr.isUncachable = IsMMIOAddress(logAddr);
    phyAddr.isIO = 1'b0;
    return phyAddr;
endfunction

function automatic logic IsPhyAddrIO(input PhyAddrPath phyAddr);
    return phyAddr.isIO;
endfunction

function automatic logic IsPhyAddrUncachable(input PhyAddrPath phyAddr);
    return phyAddr.isUncachable;
endfunction

endpackage
