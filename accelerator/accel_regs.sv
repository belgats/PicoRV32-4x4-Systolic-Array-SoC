module accel_regs
  import soc_pkg::*;
(
    input  logic          clk_i,
    input  logic          rst_ni,

    input  soc_axi_req_t  req_i,
    output soc_axi_resp_t resp_o,

    output logic          start_o,
    output logic [31:0]   debug_value_o
);

    localparam logic [31:0] CTRL_OFFSET   = 32'h0000_0000;
    localparam logic [31:0] STATUS_OFFSET = 32'h0000_0004;

    logic [31:0] ctrl_reg;
    logic [31:0] status_reg;

    logic        b_valid_q;
    logic        r_valid_q;
    logic [31:0] r_data_q;

    wire write_fire =
        req_i.aw_valid &&
        req_i.w_valid &&
        resp_o.aw_ready &&
        resp_o.w_ready;

    wire read_fire =
        req_i.ar_valid &&
        resp_o.ar_ready;

    assign start_o       = ctrl_reg[0];
    assign debug_value_o = ctrl_reg;

    always_comb begin
        resp_o = '0;

        // Accept one write when no response is pending
        resp_o.aw_ready = !b_valid_q;
        resp_o.w_ready  = !b_valid_q;

        resp_o.b_valid  = b_valid_q;
        resp_o.b.resp   = axi_pkg::RESP_OKAY;

        // Accept one read when no response is pending
        resp_o.ar_ready = !r_valid_q;

        resp_o.r_valid  = r_valid_q;
        resp_o.r.data   = r_data_q;
        resp_o.r.resp   = axi_pkg::RESP_OKAY;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ctrl_reg   <= 32'd0;
            status_reg <= 32'd0;

            b_valid_q  <= 1'b0;
            r_valid_q  <= 1'b0;
            r_data_q   <= 32'd0;
        end else begin

            // -------------------------------------------------
            // WRITE
            // -------------------------------------------------

            if (write_fire) begin
                case (req_i.aw.addr[7:0])

                    CTRL_OFFSET[7:0]: begin
                        if (req_i.w.strb[0])
                            ctrl_reg[7:0] <= req_i.w.data[7:0];

                        if (req_i.w.strb[1])
                            ctrl_reg[15:8] <= req_i.w.data[15:8];

                        if (req_i.w.strb[2])
                            ctrl_reg[23:16] <= req_i.w.data[23:16];

                        if (req_i.w.strb[3])
                            ctrl_reg[31:24] <= req_i.w.data[31:24];

                        // For milestone 1:
                        // immediately claim computation finished.
                        status_reg[0] <= 1'b1;
                    end

                    default: begin
                    end

                endcase

                b_valid_q <= 1'b1;
            end

            if (b_valid_q && req_i.b_ready)
                b_valid_q <= 1'b0;

            // -------------------------------------------------
            // READ
            // -------------------------------------------------

            if (read_fire) begin
                case (req_i.ar.addr[7:0])

                    CTRL_OFFSET[7:0]:
                        r_data_q <= ctrl_reg;

                    STATUS_OFFSET[7:0]:
                        r_data_q <= status_reg;

                    default:
                        r_data_q <= 32'hDEAD_BEEF;

                endcase

                r_valid_q <= 1'b1;
            end

            if (r_valid_q && req_i.r_ready)
                r_valid_q <= 1'b0;
        end
    end

endmodule
