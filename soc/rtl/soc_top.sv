module soc_top
  import soc_pkg::*;
(
    input  logic clk_i,
    input  logic rst_ni,

    output logic trap_o,
    output logic accel_start_o,
    output logic [31:0] accel_debug_o
);

    soc_axi_req_t  cpu_req;
    soc_axi_resp_t cpu_resp;

    soc_axi_req_t  [1:0] xbar_req;
    soc_axi_resp_t [1:0] xbar_resp;

    soc_axi_req_t  [0:0] slv_req;
    soc_axi_resp_t [0:0] slv_resp;

    xbar_rule_t [1:0] addr_map;

    // ---------------------------------------------------------
    // PicoRV32 raw AXI signals
    // ---------------------------------------------------------

    logic        awvalid;
    logic        awready;
    logic [31:0] awaddr;
    logic [2:0]  awprot;

    logic        wvalid;
    logic        wready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;

    logic        bvalid;
    logic        bready;

    logic        arvalid;
    logic        arready;
    logic [31:0] araddr;
    logic [2:0]  arprot;

    logic        rvalid;
    logic        rready;
    logic [31:0] rdata;

    // ---------------------------------------------------------
    // PicoRV32
    // ---------------------------------------------------------

    picorv32_axi #(
        .ENABLE_MUL  (1),
        .ENABLE_DIV  (1),
        .STACKADDR   (32'h0001_0000),
        .PROGADDR_RESET(32'h0000_0000)
    ) cpu (
        .clk(clk_i),
        .resetn(rst_ni),

        .trap(trap_o),

        .mem_axi_awvalid(awvalid),
        .mem_axi_awready(awready),
        .mem_axi_awaddr (awaddr),
        .mem_axi_awprot (awprot),

        .mem_axi_wvalid(wvalid),
        .mem_axi_wready(wready),
        .mem_axi_wdata (wdata),
        .mem_axi_wstrb (wstrb),

        .mem_axi_bvalid(bvalid),
        .mem_axi_bready(bready),

        .mem_axi_arvalid(arvalid),
        .mem_axi_arready(arready),
        .mem_axi_araddr (araddr),
        .mem_axi_arprot (arprot),

        .mem_axi_rvalid(rvalid),
        .mem_axi_rready(rready),
        .mem_axi_rdata (rdata),

        .pcpi_wr(1'b0),
        .pcpi_rd(32'd0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),

        .irq(32'd0)
    );

    // ---------------------------------------------------------
    // Convert PicoRV32 scalar AXI-Lite → PULP AXI structs
    // ---------------------------------------------------------

    always_comb begin
        cpu_req = '0;

        cpu_req.aw.addr  = awaddr;
        cpu_req.aw.prot  = axi_pkg::prot_t'(awprot);
        cpu_req.aw_valid = awvalid;

        cpu_req.w.data   = wdata;
        cpu_req.w.strb   = wstrb;
        cpu_req.w_valid  = wvalid;

        cpu_req.b_ready  = bready;

        cpu_req.ar.addr  = araddr;
        cpu_req.ar.prot  = axi_pkg::prot_t'(arprot);
        cpu_req.ar_valid = arvalid;

        cpu_req.r_ready  = rready;
    end

    assign awready = cpu_resp.aw_ready;
    assign wready  = cpu_resp.w_ready;

    assign bvalid  = cpu_resp.b_valid;

    assign arready = cpu_resp.ar_ready;

    assign rvalid  = cpu_resp.r_valid;
    assign rdata   = cpu_resp.r.data;

    assign slv_req[0] = cpu_req;
    assign cpu_resp   = slv_resp[0];

    // ---------------------------------------------------------
    // Address map
    // ---------------------------------------------------------

    always_comb begin
        addr_map[0] = '{
            idx:        0,
            start_addr: 32'h0000_0000,
            end_addr:   32'h0001_0000
        };

        addr_map[1] = '{
            idx:        1,
            start_addr: 32'h1000_0000,
            end_addr:   32'h1000_0100
        };
    end

    // ---------------------------------------------------------
    // PULP AXI-Lite crossbar
    // ---------------------------------------------------------

    axi_lite_xbar #(
        .Cfg        (XBAR_CFG),
        .aw_chan_t  (soc_axi_aw_chan_t),
        .w_chan_t   (soc_axi_w_chan_t),
        .b_chan_t   (soc_axi_b_chan_t),
        .ar_chan_t  (soc_axi_ar_chan_t),
        .r_chan_t   (soc_axi_r_chan_t),
        .axi_req_t  (soc_axi_req_t),
        .axi_resp_t (soc_axi_resp_t),
        .rule_t     (xbar_rule_t)
    ) xbar (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .test_i(1'b0),

        .slv_ports_req_i (slv_req),
        .slv_ports_resp_o(slv_resp),

        .mst_ports_req_o (xbar_req),
        .mst_ports_resp_i(xbar_resp),

        .addr_map_i(addr_map),

        .en_default_mst_port_i('0),
        .default_mst_port_i('0)
    );


    // ---------------------------------------------------------
    // Accelerator
    // ---------------------------------------------------------

    accel_regs #(
        .req_t  (soc_axi_req_t),
        .resp_t (soc_axi_resp_t)
    ) accel (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .req_i (xbar_req[1]),
        .resp_o(xbar_resp[1]),

        .start_o      (accel_start_o),
        .debug_value_o(accel_debug_o)
    );
   // ---------------------------------------------------------
   // RAM
   // ---------------------------------------------------------

   axi_lite_ram #(
       .WORDS    (16384),
       .HEX_FILE ("firmware/firmware.hex"),
       .req_t    (soc_axi_req_t),
       .resp_t   (soc_axi_resp_t)
   ) ram (
       .clk_i  (clk_i),
       .rst_ni (rst_ni),
   
       .req_i  (xbar_req[0]),
       .resp_o (xbar_resp[0])
   );

endmodule
