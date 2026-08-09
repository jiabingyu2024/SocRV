#  NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
#  This is an automatically generated file by jiabingyu on Sun Aug  9 15:55:20 CST 2026
# 
#  cmd:    veer -target=high_perf -snapshot=eh1_stage_a -ahb_lite -iccm_enable=1 -iccm_size=128 -iccm_region=0 -iccm_offset=0x00000000 -dccm_enable=1 -dccm_size=64 -dccm_region=0 -dccm_offset=0x00020000 -icache_enable=0 -pic_size=32 -pic_total_int=8 -pic_region=0 -pic_offset=0x00030000 -fpga_optimize -set=reset_vec=0 
# 
# To use this in a perf script, use 'require $RV_ROOT/configs/config.pl'
# Reference the hash via $config{name}..


%config = (
            'tec_rv_icg' => 'clockhdr',
            'reset_vec' => '0',
            'harts' => 1,
            'nmi_vec' => '0x11110000',
            'memmap' => {
                          'serialio' => '0xf0580000',
                          'unused_region2' => '0x20000000',
                          'unused_region4' => '0x40000000',
                          'unused_region7' => '0x70000000',
                          'unused_region8' => '0x80000000',
                          'unused_region1' => '0x10000000',
                          'debug_sb_mem' => '0xd0580000',
                          'external_data' => '0xe0580000',
                          'external_prog' => '0xd0000000',
                          'unused_region6' => '0x60000000',
                          'external_data_1' => '0x00000000',
                          'unused_region10' => '0xa0000000',
                          'consoleio' => '0xf0580000',
                          'unused_region5' => '0x50000000',
                          'unused_region11' => '0xb0000000',
                          'unused_region3' => '0x30000000',
                          'unused_region9' => '0x90000000'
                        },
            'retstack' => {
                            'ret_stack_size' => '4'
                          },
            'max_mmode_perf_event' => '50',
            'bus' => {
                       'dma_bus_tag' => '1',
                       'lsu_bus_tag' => 4,
                       'ifu_bus_tag' => '3',
                       'sb_bus_tag' => '1'
                     },
            'even_odd_trigger_chains' => 'true',
            'triggers' => [
                            {
                              'poke_mask' => [
                                               '0x081818c7',
                                               '0xffffffff',
                                               '0x00000000'
                                             ],
                              'reset' => [
                                           '0x23e00000',
                                           '0x00000000',
                                           '0x00000000'
                                         ],
                              'mask' => [
                                          '0x081818c7',
                                          '0xffffffff',
                                          '0x00000000'
                                        ]
                            },
                            {
                              'reset' => [
                                           '0x23e00000',
                                           '0x00000000',
                                           '0x00000000'
                                         ],
                              'mask' => [
                                          '0x081810c7',
                                          '0xffffffff',
                                          '0x00000000'
                                        ],
                              'poke_mask' => [
                                               '0x081810c7',
                                               '0xffffffff',
                                               '0x00000000'
                                             ]
                            },
                            {
                              'poke_mask' => [
                                               '0x081818c7',
                                               '0xffffffff',
                                               '0x00000000'
                                             ],
                              'mask' => [
                                          '0x081818c7',
                                          '0xffffffff',
                                          '0x00000000'
                                        ],
                              'reset' => [
                                           '0x23e00000',
                                           '0x00000000',
                                           '0x00000000'
                                         ]
                            },
                            {
                              'mask' => [
                                          '0x081810c7',
                                          '0xffffffff',
                                          '0x00000000'
                                        ],
                              'reset' => [
                                           '0x23e00000',
                                           '0x00000000',
                                           '0x00000000'
                                         ],
                              'poke_mask' => [
                                               '0x081810c7',
                                               '0xffffffff',
                                               '0x00000000'
                                             ]
                            }
                          ],
            'verilator' => '',
            'core' => {
                        'dma_buf_depth' => '4',
                        'lsu_num_nbload' => '8',
                        'lsu_num_nbload_width' => '3',
                        'dec_instbuf_depth' => '4',
                        'lsu_stbuf_depth' => '8',
                        'fpga_optimize' => 1
                      },
            'numiregs' => '32',
            'testbench' => {
                             'ext_addrwidth' => '32',
                             'build_ahb_lite' => '1',
                             'SDVT_AHB' => '1',
                             'datawidth' => '64',
                             'CPU_TOP' => '`RV_TOP.veer',
                             'assert_on' => '',
                             'ext_datawidth' => '64',
                             'lderr_rollback' => '1',
                             'RV_TOP' => '`TOP.rvtop',
                             'TOP' => 'tb_top',
                             'clock_period' => '100',
                             'sterr_rollback' => '0'
                           },
            'physical' => '1',
            'dccm' => {
                        'dccm_sadr' => '0x20000',
                        'dccm_offset' => '0x00020000',
                        'dccm_reserved' => '0x1000',
                        'dccm_fdata_width' => 39,
                        'dccm_data_width' => 32,
                        'dccm_bank_bits' => 3,
                        'dccm_bits' => 16,
                        'dccm_rows' => '2048',
                        'dccm_ecc_width' => 7,
                        'dccm_width_bits' => 2,
                        'dccm_region' => '0',
                        'dccm_num_banks' => '8',
                        'dccm_data_cell' => 'ram_2048x39',
                        'dccm_size' => 64,
                        'dccm_index_bits' => 11,
                        'dccm_eadr' => '0x2ffff',
                        'dccm_size_64' => '',
                        'dccm_enable' => '1',
                        'dccm_num_banks_8' => '',
                        'dccm_byte_width' => '4',
                        'lsu_sb_bits' => 16
                      },
            'icache' => {
                          'icache_tag_cell' => 'ram_128x21',
                          'icache_ic_rows' => '512',
                          'icache_tag_low' => '6',
                          'icache_tag_depth' => 128,
                          'icache_ic_index' => 9,
                          'icache_size' => 32,
                          'icache_ic_depth' => 9,
                          'icache_tag_high' => 13,
                          'icache_taddr_high' => 6,
                          'icache_data_cell' => 'ram_512x34'
                        },
            'btb' => {
                       'btb_addr_lo' => '4',
                       'btb_size' => 512,
                       'btb_index2_lo' => 10,
                       'btb_index3_lo' => 16,
                       'btb_addr_hi' => 9,
                       'btb_index1_hi' => 9,
                       'btb_index3_hi' => 21,
                       'btb_index1_lo' => '4',
                       'btb_btag_size' => 5,
                       'btb_array_depth' => 64,
                       'btb_index2_hi' => 15
                     },
            'bht' => {
                       'bht_addr_hi' => 11,
                       'bht_addr_lo' => '4',
                       'bht_ghr_pad2' => 'fghr[8:3],2\'b0',
                       'bht_size' => 2048,
                       'bht_ghr_range' => '8:0',
                       'bht_ghr_pad' => 'fghr[8:4],3\'b0',
                       'bht_ghr_size' => 9,
                       'bht_hash_string' => '{ghr[7:6] ^ {ghr[7+1], {8-1-6{1\'b0} } },hashin[9:4]^ghr[6-1:0]}',
                       'bht_array_depth' => 256
                     },
            'protection' => {
                              'inst_access_mask6' => '0xffffffff',
                              'inst_access_addr3' => '0x00000000',
                              'inst_access_enable0' => '0x0',
                              'data_access_enable5' => '0x0',
                              'data_access_mask7' => '0xffffffff',
                              'data_access_mask2' => '0xffffffff',
                              'data_access_enable7' => '0x0',
                              'inst_access_addr2' => '0x00000000',
                              'inst_access_addr7' => '0x00000000',
                              'inst_access_enable4' => '0x0',
                              'data_access_mask3' => '0xffffffff',
                              'inst_access_enable2' => '0x0',
                              'data_access_addr6' => '0x00000000',
                              'data_access_addr1' => '0x00000000',
                              'data_access_enable3' => '0x0',
                              'inst_access_enable6' => '0x0',
                              'data_access_mask4' => '0xffffffff',
                              'inst_access_mask0' => '0xffffffff',
                              'data_access_addr5' => '0x00000000',
                              'data_access_enable1' => '0x0',
                              'inst_access_mask5' => '0xffffffff',
                              'data_access_addr0' => '0x00000000',
                              'inst_access_addr4' => '0x00000000',
                              'inst_access_mask1' => '0xffffffff',
                              'inst_access_enable1' => '0x0',
                              'data_access_mask5' => '0xffffffff',
                              'data_access_addr4' => '0x00000000',
                              'inst_access_addr0' => '0x00000000',
                              'data_access_mask1' => '0xffffffff',
                              'inst_access_addr1' => '0x00000000',
                              'inst_access_enable3' => '0x0',
                              'data_access_enable6' => '0x0',
                              'inst_access_mask4' => '0xffffffff',
                              'data_access_mask0' => '0xffffffff',
                              'inst_access_addr5' => '0x00000000',
                              'data_access_addr2' => '0x00000000',
                              'data_access_addr7' => '0x00000000',
                              'data_access_enable4' => '0x0',
                              'inst_access_mask3' => '0xffffffff',
                              'data_access_enable2' => '0x0',
                              'inst_access_addr6' => '0x00000000',
                              'data_access_mask6' => '0xffffffff',
                              'data_access_enable0' => '0x0',
                              'data_access_addr3' => '0x00000000',
                              'inst_access_enable5' => '0x0',
                              'inst_access_mask7' => '0xffffffff',
                              'inst_access_mask2' => '0xffffffff',
                              'inst_access_enable7' => '0x0'
                            },
            'csr' => {
                       'pmpcfg2' => {
                                      'exists' => 'false'
                                    },
                       'mitbnd0' => {
                                      'reset' => '0xffffffff',
                                      'mask' => '0xffffffff',
                                      'exists' => 'true',
                                      'number' => '0x7d3'
                                    },
                       'pmpaddr5' => {
                                       'exists' => 'false'
                                     },
                       'mhpmevent3' => {
                                         'exists' => 'true',
                                         'reset' => '0x0',
                                         'mask' => '0xffffffff'
                                       },
                       'mhpmcounter4' => {
                                           'exists' => 'true',
                                           'mask' => '0xffffffff',
                                           'reset' => '0x0'
                                         },
                       'mie' => {
                                  'exists' => 'true',
                                  'mask' => '0x70000888',
                                  'reset' => '0x0'
                                },
                       'mdccmect' => {
                                       'mask' => '0xffffffff',
                                       'reset' => '0x0',
                                       'number' => '0x7f2',
                                       'exists' => 'true'
                                     },
                       'mhpmevent4' => {
                                         'exists' => 'true',
                                         'reset' => '0x0',
                                         'mask' => '0xffffffff'
                                       },
                       'meicpct' => {
                                      'number' => '0xbca',
                                      'exists' => 'true',
                                      'mask' => '0x0',
                                      'comment' => 'External claim id/priority capture.',
                                      'reset' => '0x0'
                                    },
                       'mvendorid' => {
                                        'exists' => 'true',
                                        'mask' => '0x0',
                                        'reset' => '0x45'
                                      },
                       'pmpcfg1' => {
                                      'exists' => 'false'
                                    },
                       'mcpc' => {
                                   'exists' => 'true',
                                   'number' => '0x7c2',
                                   'reset' => '0x0',
                                   'mask' => '0x0'
                                 },
                       'miccmect' => {
                                       'reset' => '0x0',
                                       'mask' => '0xffffffff',
                                       'exists' => 'true',
                                       'number' => '0x7f1'
                                     },
                       'marchid' => {
                                      'exists' => 'true',
                                      'mask' => '0x0',
                                      'reset' => '0x0000000b'
                                    },
                       'mhpmcounter5h' => {
                                            'exists' => 'true',
                                            'mask' => '0xffffffff',
                                            'reset' => '0x0'
                                          },
                       'dicad0' => {
                                     'debug' => 'true',
                                     'reset' => '0x0',
                                     'comment' => 'Cache diagnostics.',
                                     'exists' => 'true',
                                     'number' => '0x7c9',
                                     'mask' => '0xffffffff'
                                   },
                       'mcounteren' => {
                                         'exists' => 'false'
                                       },
                       'cycle' => {
                                    'exists' => 'false'
                                  },
                       'mitbnd1' => {
                                      'exists' => 'true',
                                      'number' => '0x7d6',
                                      'mask' => '0xffffffff',
                                      'reset' => '0xffffffff'
                                    },
                       'mhpmcounter6' => {
                                           'exists' => 'true',
                                           'mask' => '0xffffffff',
                                           'reset' => '0x0'
                                         },
                       'pmpaddr7' => {
                                       'exists' => 'false'
                                     },
                       'mhpmcounter3h' => {
                                            'reset' => '0x0',
                                            'mask' => '0xffffffff',
                                            'exists' => 'true'
                                          },
                       'mcountinhibit' => {
                                            'exists' => 'false'
                                          },
                       'pmpaddr1' => {
                                       'exists' => 'false'
                                     },
                       'instret' => {
                                      'exists' => 'false'
                                    },
                       'pmpaddr0' => {
                                       'exists' => 'false'
                                     },
                       'pmpaddr4' => {
                                       'exists' => 'false'
                                     },
                       'mhpmevent5' => {
                                         'exists' => 'true',
                                         'mask' => '0xffffffff',
                                         'reset' => '0x0'
                                       },
                       'time' => {
                                   'exists' => 'false'
                                 },
                       'pmpcfg0' => {
                                      'exists' => 'false'
                                    },
                       'micect' => {
                                     'number' => '0x7f0',
                                     'exists' => 'true',
                                     'reset' => '0x0',
                                     'mask' => '0xffffffff'
                                   },
                       'mcgc' => {
                                   'reset' => '0x0',
                                   'mask' => '0x000001ff',
                                   'poke_mask' => '0x000001ff',
                                   'number' => '0x7f8',
                                   'exists' => 'true'
                                 },
                       'dcsr' => {
                                   'reset' => '0x40000003',
                                   'mask' => '0x00008c04',
                                   'poke_mask' => '0x00008dcc',
                                   'exists' => 'true'
                                 },
                       'mitcnt0' => {
                                      'mask' => '0xffffffff',
                                      'reset' => '0x0',
                                      'number' => '0x7d2',
                                      'exists' => 'true'
                                    },
                       'pmpaddr10' => {
                                        'exists' => 'false'
                                      },
                       'pmpaddr13' => {
                                        'exists' => 'false'
                                      },
                       'tselect' => {
                                      'reset' => '0x0',
                                      'mask' => '0x3',
                                      'exists' => 'true'
                                    },
                       'dicad1' => {
                                     'debug' => 'true',
                                     'reset' => '0x0',
                                     'comment' => 'Cache diagnostics.',
                                     'exists' => 'true',
                                     'number' => '0x7ca',
                                     'mask' => '0x3'
                                   },
                       'mgpmc' => {
                                    'reset' => '0x1',
                                    'mask' => '0x1',
                                    'exists' => 'true',
                                    'number' => '0x7d0'
                                  },
                       'dicawics' => {
                                       'debug' => 'true',
                                       'reset' => '0x0',
                                       'comment' => 'Cache diagnostics.',
                                       'exists' => 'true',
                                       'number' => '0x7c8',
                                       'mask' => '0x0130fffc'
                                     },
                       'dmst' => {
                                   'reset' => '0x0',
                                   'comment' => 'Memory synch trigger: Flush caches in debug mode.',
                                   'debug' => 'true',
                                   'mask' => '0x0',
                                   'exists' => 'true',
                                   'number' => '0x7c4'
                                 },
                       'pmpcfg3' => {
                                      'exists' => 'false'
                                    },
                       'mitctl1' => {
                                      'number' => '0x7d7',
                                      'exists' => 'true',
                                      'mask' => '0x00000007',
                                      'reset' => '0x1'
                                    },
                       'mhpmcounter5' => {
                                           'reset' => '0x0',
                                           'mask' => '0xffffffff',
                                           'exists' => 'true'
                                         },
                       'meipt' => {
                                    'number' => '0xbc9',
                                    'exists' => 'true',
                                    'reset' => '0x0',
                                    'comment' => 'External interrupt priority threshold.',
                                    'mask' => '0xf'
                                  },
                       'meicurpl' => {
                                       'number' => '0xbcc',
                                       'exists' => 'true',
                                       'mask' => '0xf',
                                       'comment' => 'External interrupt current priority level.',
                                       'reset' => '0x0'
                                     },
                       'pmpaddr9' => {
                                       'exists' => 'false'
                                     },
                       'mhpmcounter4h' => {
                                            'reset' => '0x0',
                                            'mask' => '0xffffffff',
                                            'exists' => 'true'
                                          },
                       'mfdc' => {
                                   'mask' => '0x000727ff',
                                   'reset' => '0x00070000',
                                   'number' => '0x7f9',
                                   'exists' => 'true'
                                 },
                       'pmpaddr2' => {
                                       'exists' => 'false'
                                     },
                       'mip' => {
                                  'mask' => '0x0',
                                  'reset' => '0x0',
                                  'exists' => 'true',
                                  'poke_mask' => '0x70000888'
                                },
                       'mimpid' => {
                                     'mask' => '0x0',
                                     'reset' => '0x6',
                                     'exists' => 'true'
                                   },
                       'mitctl0' => {
                                      'exists' => 'true',
                                      'number' => '0x7d4',
                                      'mask' => '0x00000007',
                                      'reset' => '0x1'
                                    },
                       'pmpaddr15' => {
                                        'exists' => 'false'
                                      },
                       'pmpaddr6' => {
                                       'exists' => 'false'
                                     },
                       'misa' => {
                                   'exists' => 'true',
                                   'mask' => '0x0',
                                   'reset' => '0x40001104'
                                 },
                       'pmpaddr8' => {
                                       'exists' => 'false'
                                     },
                       'mstatus' => {
                                      'exists' => 'true',
                                      'mask' => '0x88',
                                      'reset' => '0x1800'
                                    },
                       'mitcnt1' => {
                                      'number' => '0x7d5',
                                      'exists' => 'true',
                                      'reset' => '0x0',
                                      'mask' => '0xffffffff'
                                    },
                       'dicago' => {
                                     'comment' => 'Cache diagnostics.',
                                     'reset' => '0x0',
                                     'debug' => 'true',
                                     'mask' => '0x0',
                                     'number' => '0x7cb',
                                     'exists' => 'true'
                                   },
                       'mpmc' => {
                                   'reset' => '0x2',
                                   'comment' => 'FWHALT',
                                   'mask' => '0x2',
                                   'number' => '0x7c6',
                                   'exists' => 'true',
                                   'poke_mask' => '0x2'
                                 },
                       'pmpaddr3' => {
                                       'exists' => 'false'
                                     },
                       'pmpaddr12' => {
                                        'exists' => 'false'
                                      },
                       'mhpmcounter6h' => {
                                            'reset' => '0x0',
                                            'mask' => '0xffffffff',
                                            'exists' => 'true'
                                          },
                       'pmpaddr11' => {
                                        'exists' => 'false'
                                      },
                       'mhpmevent6' => {
                                         'mask' => '0xffffffff',
                                         'reset' => '0x0',
                                         'exists' => 'true'
                                       },
                       'meicidpl' => {
                                       'reset' => '0x0',
                                       'comment' => 'External interrupt claim id priority level.',
                                       'mask' => '0xf',
                                       'exists' => 'true',
                                       'number' => '0xbcb'
                                     },
                       'mhpmcounter3' => {
                                           'reset' => '0x0',
                                           'mask' => '0xffffffff',
                                           'exists' => 'true'
                                         },
                       'pmpaddr14' => {
                                        'exists' => 'false'
                                      }
                     },
            'pic' => {
                       'pic_meigwctrl_mask' => '0x3',
                       'pic_total_int_plus1' => 9,
                       'pic_meipt_offset' => '0x3004',
                       'pic_meipl_mask' => '0xf',
                       'pic_meipl_count' => '8',
                       'pic_mpiccfg_mask' => '0x1',
                       'pic_meie_count' => '8',
                       'pic_meip_count' => 4,
                       'pic_int_words' => 1,
                       'pic_offset' => '0x00030000',
                       'pic_meipt_count' => '8',
                       'pic_bits' => 15,
                       'pic_mpiccfg_offset' => '0x3000',
                       'pic_meigwctrl_offset' => '0x4000',
                       'pic_meie_offset' => '0x2000',
                       'pic_total_int' => 8,
                       'pic_meigwctrl_count' => '8',
                       'pic_meip_mask' => '0x0',
                       'pic_meigwclr_count' => '8',
                       'pic_meipl_offset' => '0x0000',
                       'pic_mpiccfg_count' => 1,
                       'pic_meie_mask' => '0x1',
                       'pic_base_addr' => '0x30000',
                       'pic_size' => 32,
                       'pic_meipt_mask' => '0x0',
                       'pic_region' => '0',
                       'pic_meigwclr_mask' => '0x0',
                       'pic_meigwclr_offset' => '0x5000',
                       'pic_meip_offset' => '0x1000'
                     },
            'num_mmode_perf_regs' => '4',
            'xlen' => 32,
            'iccm' => {
                        'iccm_bits' => 17,
                        'iccm_rows' => '4096',
                        'iccm_bank_bits' => 3,
                        'iccm_reserved' => '0x1000',
                        'iccm_offset' => '0x00000000',
                        'iccm_sadr' => '0x00000000',
                        'iccm_size_128' => '',
                        'iccm_enable' => '1',
                        'iccm_num_banks_8' => '',
                        'iccm_data_cell' => 'ram_4096x39',
                        'iccm_size' => 128,
                        'iccm_eadr' => '0x0001ffff',
                        'iccm_index_bits' => 12,
                        'iccm_num_banks' => '8',
                        'iccm_region' => '0'
                      },
            'target' => 'high_perf',
            'regwidth' => '32'
          );
1;
