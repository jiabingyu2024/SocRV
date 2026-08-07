// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.


//
// --- Core module
//
// プロセッサ・コアに含まれる全てのモジュールをインスタンシエートし、
// インターフェースで接続する

import BasicTypes::*;
import CacheSystemTypes::*;
import MemoryTypes::*;
import MemoryMapTypes::*;
import IO_UnitTypes::*;
import DebugTypes::*;

module Core (
input
    logic clk,
    logic rst, rstStart,
    MemAccessReqAck icMemAccessReqAck_i,
    MemAccessResult icMemAccessResult_i,
    MemAccessReqAck dcMemAccessReqAck_i,
    MemAccessResult dcMemAccessResult_i,
    MemAccessResponse dcMemAccessResponse_i,
    logic reqSoftwareInterrupt,
    logic reqTimerInterrupt,
    logic reqExternalInterrupt,
    ExternalInterruptCodePath externalInterruptCode,
output
    DebugRegister debugRegister,
    PC_Path lastCommittedPC,
    MemReadAccessReq icMemAccessReq_o,
    MemAccessReq dcMemAccessReq_o,
    logic serialWE,
    SerialDataPath serialWriteData
);
    //
    // --- For Debug
    //
    DebugIF debugIF( clk, rst );
    PerformanceCounterIF perfCounterIF( clk, rst );

    assign debugRegister = debugIF.debugRegister;

`ifndef RSD_DISABLE_DEBUG_REGISTER
    Debug debug ( debugIF, lastCommittedPC );
`else
    always_ff @(posedge clk) begin
        lastCommittedPC <= debugIF.lastCommittedPC;
    end
`endif

`ifndef RSD_DISABLE_PERFORMANCE_COUNTER
    PerformanceCounter perfCounter(perfCounterIF, debugIF);
`endif

    //
    // --- Interfaces
    //

    // Pipeline control logic
    ControllerIF ctrlIF( clk, rst );

    // Pipeline stages
    NextPCStageIF npStageIF( clk, rst, rstStart );
    FetchStageIF ifStageIF( clk, rst, rstStart );
    PreDecodeStageIF pdStageIF( clk, rst );
    DecodeStageIF idStageIF( clk, rst );
    RenameStageIF rnStageIF( clk, rst, rstStart );
    //DispatchStageIF dsStageIF( clk, rst );
    ScheduleStageIF scStageIF( clk, rst );

    IntegerIssueStageIF intIsStageIF( clk, rst );
    IntegerRegisterReadStageIF intRrStageIF( clk, rst );
    IntegerExecutionStageIF intExStageIF( clk, rst );
    //IntegerRegisterWriteStageIF intRwStageIF( clk, rst );

    ComplexIntegerIssueStageIF complexIsStageIF( clk, rst );
    ComplexIntegerRegisterReadStageIF complexRrStageIF( clk, rst );
    ComplexIntegerExecutionStageIF complexExStageIF( clk, rst );

    MemoryIssueStageIF memIsStageIF( clk, rst );
    MemoryRegisterReadStageIF memRrStageIF( clk, rst );
    MemoryExecutionStageIF memExStageIF( clk, rst );
    MemoryTagAccessStageIF mtStageIF( clk, rst );
    MemoryAccessStageIF maStageIF( clk, rst );
    //MemoryRegisterWriteStageIF memRwStageIF( clk, rst );
    
    FPIssueStageIF fpIsStageIF( clk, rst );
    FPRegisterReadStageIF fpRrStageIF( clk, rst );
    FPExecutionStageIF fpExStageIF( clk, rst );
    FPDivSqrtUnitIF fpDivSqrtUnitIF(clk, rst);

    CommitStageIF cmStageIF( clk, rst );

    // Other interfaces.
    CacheSystemIF cacheSystemIF( clk, rst );
    RenameLogicIF renameLogicIF( clk, rst, rstStart );
    ActiveListIF activeListIF( clk, rst );
    SchedulerIF schedulerIF( clk, rst, rstStart );
    WakeupSelectIF wakeupSelectIF( clk, rst, rstStart );
    RegisterFileIF registerFileIF( clk, rst, rstStart );
    BypassNetworkIF bypassNetworkIF( clk, rst, rstStart );
    LoadStoreUnitIF loadStoreUnitIF( clk, rst, rstStart );
    RecoveryManagerIF recoveryManagerIF( clk, rst );
    CSR_UnitIF csrUnitIF(clk, rst, rstStart, reqSoftwareInterrupt,
        reqTimerInterrupt, reqExternalInterrupt, externalInterruptCode);
    IO_UnitIF ioUnitIF(clk, rst, rstStart, serialWE, serialWriteData);
    MulDivUnitIF mulDivUnitIF(clk, rst);
    CacheFlushManagerIF cacheFlushManagerIF(clk, rst);

    //
    // --- Modules
    //
    Controller controller( ctrlIF, debugIF );
    // Expose the ICache and DCache boundaries independently.  The original
    // RSD MemoryAccessController serialized both caches behind one port;
    // SocRV keeps the two HXI masters independent.
    assign icMemAccessReq_o = cacheSystemIF.icMemAccessReq;
    assign dcMemAccessReq_o = cacheSystemIF.dcMemAccessReq;
    assign cacheSystemIF.icMemAccessReqAck = icMemAccessReqAck_i;
    assign cacheSystemIF.icMemAccessResult = icMemAccessResult_i;
    assign cacheSystemIF.dcMemAccessReqAck = dcMemAccessReqAck_i;
    assign cacheSystemIF.dcMemAccessResult = dcMemAccessResult_i;
    assign cacheSystemIF.dcMemAccessResponse = dcMemAccessResponse_i;


    NextPCStage npStage( npStageIF, ifStageIF, recoveryManagerIF, ctrlIF, debugIF );
        PC pc( npStageIF );
        BTB btb( npStageIF, ifStageIF );
        BranchPredictor brPred( npStageIF, ifStageIF, ctrlIF );
    FetchStage ifStage( ifStageIF, npStageIF, ctrlIF, debugIF, perfCounterIF );
        ICache iCache( npStageIF, ifStageIF, cacheSystemIF );
    
    PreDecodeStage pdStage( pdStageIF, ifStageIF, ctrlIF, debugIF );
    DecodeStage idStage( idStageIF, pdStageIF, ctrlIF, debugIF, perfCounterIF );

    RenameStage rnStage( rnStageIF, idStageIF, renameLogicIF, activeListIF, schedulerIF, loadStoreUnitIF, recoveryManagerIF, ctrlIF, debugIF );
        RenameLogic renameLogic( renameLogicIF, activeListIF, recoveryManagerIF );
        RenameLogicCommitter renameLogicCommitter( renameLogicIF, activeListIF, recoveryManagerIF );
        ActiveList activeList( activeListIF, recoveryManagerIF, ctrlIF, debugIF );
        RMT rmt_wat( renameLogicIF );
        RetirementRMT retirementRMT( renameLogicIF );
        MemoryDependencyPredictor memoryDependencyPredictor( rnStageIF, loadStoreUnitIF );
    
    DispatchStage dsStage( /*dsStageIF,*/ rnStageIF, schedulerIF, ctrlIF, debugIF );

    ScheduleStage scStage( scStageIF, schedulerIF, recoveryManagerIF, ctrlIF );
        IssueQueue issueQueue( schedulerIF, wakeupSelectIF, recoveryManagerIF, debugIF );
        ReplayQueue replayQueue( schedulerIF, loadStoreUnitIF, mulDivUnitIF, fpDivSqrtUnitIF, cacheFlushManagerIF, recoveryManagerIF, ctrlIF );
        Scheduler scheduler( schedulerIF, wakeupSelectIF, recoveryManagerIF, mulDivUnitIF, fpDivSqrtUnitIF, debugIF );
        WakeupPipelineRegister wakeupPipelineRegister( wakeupSelectIF, recoveryManagerIF );
        DestinationRAM destinationRAM( wakeupSelectIF );
        WakeupLogic wakeupLogic( wakeupSelectIF );
        SelectLogic selectLogic( wakeupSelectIF, recoveryManagerIF );

    IntegerIssueStage intIsStage( intIsStageIF, scStageIF, schedulerIF, recoveryManagerIF, ctrlIF, debugIF );
    IntegerRegisterReadStage intRrStage( intRrStageIF, intIsStageIF, registerFileIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF );
    IntegerExecutionStage intExStage( intExStageIF, intRrStageIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF );
    IntegerRegisterWriteStage intRwStage( /*intRwStageIF,*/ intExStageIF, schedulerIF, npStageIF, registerFileIF, activeListIF, recoveryManagerIF, ctrlIF, debugIF );

`ifndef RSD_MARCH_UNIFIED_MULDIV_MEM_PIPE
    ComplexIntegerIssueStage complexIsStage( complexIsStageIF, scStageIF, schedulerIF, recoveryManagerIF, mulDivUnitIF, ctrlIF, debugIF );
    ComplexIntegerRegisterReadStage complexRrStage( complexRrStageIF, complexIsStageIF, registerFileIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF );
    ComplexIntegerExecutionStage complexExStage( complexExStageIF, complexRrStageIF, mulDivUnitIF, schedulerIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF );
    ComplexIntegerRegisterWriteStage complexRwStage( complexExStageIF, registerFileIF, activeListIF, recoveryManagerIF, ctrlIF, debugIF );
`endif
        MulDivUnit mulDivUnit(mulDivUnitIF, recoveryManagerIF);

    MemoryIssueStage memIsStage( memIsStageIF, scStageIF, schedulerIF, recoveryManagerIF, mulDivUnitIF, ctrlIF, debugIF );
    MemoryRegisterReadStage memRrStage( memRrStageIF, memIsStageIF, registerFileIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF );
    MemoryExecutionStage memExStage( memExStageIF, memRrStageIF, loadStoreUnitIF, cacheFlushManagerIF, mulDivUnitIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, csrUnitIF, debugIF );
    MemoryTagAccessStage mtStage( mtStageIF, memExStageIF, schedulerIF, loadStoreUnitIF, mulDivUnitIF, recoveryManagerIF, ctrlIF, debugIF, perfCounterIF );
    MemoryAccessStage maStage( maStageIF, mtStageIF, loadStoreUnitIF, mulDivUnitIF, bypassNetworkIF, ioUnitIF, recoveryManagerIF, ctrlIF, debugIF );
        LoadStoreUnit loadStoreUnit( loadStoreUnitIF, ctrlIF );
        LoadQueue loadQueue( loadStoreUnitIF, recoveryManagerIF );
        StoreQueue storeQueue( loadStoreUnitIF, recoveryManagerIF );
        StoreCommitter storeCommitter(loadStoreUnitIF, recoveryManagerIF, ioUnitIF, debugIF, perfCounterIF);
        DCache dCache( loadStoreUnitIF, cacheSystemIF, ctrlIF, recoveryManagerIF);
    MemoryRegisterWriteStage memRwStage( /*memRwStageIF,*/ maStageIF, loadStoreUnitIF, registerFileIF, activeListIF, recoveryManagerIF, ctrlIF, debugIF );

`ifdef RSD_MARCH_FP_PIPE
    FPIssueStage fpIsStage( fpIsStageIF, scStageIF, schedulerIF, recoveryManagerIF, fpDivSqrtUnitIF, ctrlIF, debugIF );
    FPRegisterReadStage fpRrStage( fpRrStageIF, fpIsStageIF, registerFileIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF );
    FPExecutionStage fpExStage( fpExStageIF, fpRrStageIF, fpDivSqrtUnitIF, schedulerIF, bypassNetworkIF, recoveryManagerIF, ctrlIF, debugIF, csrUnitIF);
    FPRegisterWriteStage fpRwStage( fpExStageIF, registerFileIF, activeListIF, recoveryManagerIF, ctrlIF, debugIF );
    FPDivSqrtUnit fpDivSqrtUnit(fpDivSqrtUnitIF, recoveryManagerIF);
`endif

    RegisterFile registerFile( registerFileIF );
        BypassController bypassController( bypassNetworkIF, ctrlIF );
        BypassNetwork  bypassNetwork( bypassNetworkIF, ctrlIF );
    
    // A commitment stage generates a flush signal and this is send to scheduler.
    CommitStage cmStage( cmStageIF, renameLogicIF, activeListIF, loadStoreUnitIF, recoveryManagerIF, csrUnitIF, debugIF );
        RecoveryManager recoveryManager( recoveryManagerIF, activeListIF, csrUnitIF, ctrlIF, perfCounterIF );

    CSR_Unit csrUnit(csrUnitIF, perfCounterIF);
    CacheFlushManager cacheFlushManager( cacheFlushManagerIF, cacheSystemIF );
    InterruptController interruptCtrl(csrUnitIF, ctrlIF, npStageIF, recoveryManagerIF);
    IO_Unit ioUnit(ioUnitIF, csrUnitIF);

endmodule : Core
