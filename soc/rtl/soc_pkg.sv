`include "axi/typedef.svh"

package soc_pkg;

  typedef logic [31:0] addr_t;
  typedef logic [31:0] data_t;
  typedef logic [3:0]  strb_t;

  `AXI_LITE_TYPEDEF_ALL(soc_axi, addr_t, data_t, strb_t)

  localparam axi_pkg::xbar_cfg_t XBAR_CFG = '{
    NoSlvPorts:           1,
    NoMstPorts:           2,
    MaxMstTrans:          1,
    MaxSlvTrans:          1,
    FallThrough:          1'b0,
    LatencyMode:          axi_pkg::NO_LATENCY,
    PipelineStages:       0,
    AxiIdWidthSlvPorts:   0,
    AxiIdUsedSlvPorts:    0,
    UniqueIds:            1'b0,
    AxiAddrWidth:         32,
    AxiDataWidth:         32,
    NoAddrRules:          2
  };

  typedef axi_pkg::xbar_rule_32_t xbar_rule_t;

endpackage
