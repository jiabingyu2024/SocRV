

localparam DCCM_BITS        = `RV_DCCM_BITS;
localparam DCCM_BANK_BITS   = `RV_DCCM_BANK_BITS;
localparam DCCM_NUM_BANKS   = `RV_DCCM_NUM_BANKS;
localparam DCCM_DATA_WIDTH  = `RV_DCCM_DATA_WIDTH;
localparam DCCM_FDATA_WIDTH = `RV_DCCM_FDATA_WIDTH;
localparam DCCM_BYTE_WIDTH  = `RV_DCCM_BYTE_WIDTH;
localparam DCCM_ECC_WIDTH   = `RV_DCCM_ECC_WIDTH;

localparam LSU_RDBUF_DEPTH  = `RV_LSU_NUM_NBLOAD;
localparam LSU_STBUF_DEPTH  = `RV_LSU_STBUF_DEPTH;
localparam LSU_SB_BITS      = `RV_LSU_SB_BITS;

localparam DEC_INSTBUF_DEPTH = `RV_DEC_INSTBUF_DEPTH;

localparam ICCM_SIZE         = `RV_ICCM_SIZE;
localparam ICCM_BITS         = `RV_ICCM_BITS;
localparam ICCM_NUM_BANKS    = `RV_ICCM_NUM_BANKS;
localparam ICCM_BANK_BITS    = `RV_ICCM_BANK_BITS;
localparam ICCM_INDEX_BITS   = `RV_ICCM_INDEX_BITS;
localparam ICCM_BANK_HI      = 4 + (`RV_ICCM_BANK_BITS/4);

localparam LSU_BUS_TAG     = `RV_LSU_BUS_TAG;
localparam SB_BUS_TAG      = `RV_SB_BUS_TAG;

localparam IFU_BUS_TAG     = `RV_IFU_BUS_TAG;


