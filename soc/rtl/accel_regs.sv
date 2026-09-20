module pe (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [31:0] out
);

    logic [31:0] sum_q;

    assign out = sum_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear) begin
            sum_q <= 32'd0;
        end else begin
            sum_q <= sum_q + (a * b);
        end
    end
endmodule

module systolic_array (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic [63:0] a,
    input  logic [63:0] b,
    output logic [511:0] result
);

    logic [15:0] shift_reg_a [0:3][0:3];
    logic [15:0] shift_reg_b [0:3][0:3];
    integer      i;
    integer      j;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    shift_reg_a[i][j] <= 16'd0;
                    shift_reg_b[i][j] <= 16'd0;
                end
            end
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                shift_reg_a[0][i] <= a[16*(i+1)-1 -:16];
                shift_reg_b[i][0] <= b[16*(i+1)-1 -:16];

                for (j = 1; j < 4; j = j + 1) begin
                    shift_reg_a[j][i] <= shift_reg_a[j-1][i];
                    shift_reg_b[i][j] <= shift_reg_b[i][j-1];
                end
            end
        end
    end

    generate
        for (genvar k = 0; k < 4; k++) begin : row
            for (genvar l = 0; l < 4; l++) begin : col
                pe pe_inst (
                    .clk (clk),
                    .rst_n(rst_n),
                    .clear(clear),
                    .a   (shift_reg_a[k][l]),
                    .b   (shift_reg_b[k][l]),
                    .out (result[32*(4*k + l + 1)-1 -:32])
                );
            end
        end
    endgenerate

endmodule

module accel_regs #(
  parameter type req_t  = logic,
  parameter type resp_t = logic
)(
  input  logic  clk_i,
  input  logic  rst_ni,

  input  req_t  req_i,
  output resp_t resp_o,

  output logic  start_o,
  output logic [31:0] debug_value_o
);

  localparam logic [31:0] CTRL_OFFSET   = 32'h0000_0000;
  localparam logic [31:0] STATUS_OFFSET = 32'h0000_0004;
  localparam logic [31:0] A_STREAM_OFFSET = 32'h0000_0008;
  localparam logic [31:0] B_STREAM_OFFSET = 32'h0000_0048;
  localparam logic [31:0] RES0_OFFSET     = 32'h0000_0088;

  logic [31:0] aw_addr_q;
  logic [31:0] w_data_q;

  logic aw_pending_q;
  logic w_pending_q;

  logic b_valid_q;

  logic r_valid_q;
  logic [31:0] r_data_q;

  logic [31:0] ctrl_q;
  logic [31:0] status_q;
  logic [63:0] a_stream_q [0:7];
  logic [63:0] b_stream_q [0:7];
  logic [511:0] result_q;
  logic [511:0] systolic_result;
  logic [63:0] array_a_q;
  logic [63:0] array_b_q;
  logic [4:0] compute_cycle_q;
  logic       busy_q;
  logic       clear_array;
  logic [1:0] start_pending_q;
  logic [1:0] feed_delay_q;

  systolic_array u_systolic_array (
    .clk    (clk_i),
    .rst_n  (rst_ni),
    .clear  (clear_array),
    .a      (array_a_q),
    .b      (array_b_q),
    .result (systolic_result)
  );

  assign clear_array = |start_pending_q;

  always_comb begin
    resp_o = '0;

    resp_o.aw_ready = !aw_pending_q && !b_valid_q;
    resp_o.w_ready  = !w_pending_q  && !b_valid_q;

    resp_o.b.resp  = 2'b00;
    resp_o.b_valid = b_valid_q;

    resp_o.ar_ready = !r_valid_q;

    resp_o.r.data  = r_data_q;
    resp_o.r.resp  = 2'b00;
    resp_o.r_valid = r_valid_q;

    start_o = ctrl_q[0];
    debug_value_o = ctrl_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin

    if (!rst_ni) begin
      aw_addr_q        <= '0;
      w_data_q         <= '0;

      aw_pending_q     <= 1'b0;
      w_pending_q      <= 1'b0;

      b_valid_q        <= 1'b0;

      r_valid_q        <= 1'b0;
      r_data_q         <= '0;

      ctrl_q           <= 32'd0;
      status_q         <= 32'd0;
      for (int reset_idx = 0; reset_idx < 8; reset_idx++) begin
        a_stream_q[reset_idx] <= 64'd0;
        b_stream_q[reset_idx] <= 64'd0;
      end
      result_q         <= 512'd0;
      compute_cycle_q  <= 4'd0;
      busy_q           <= 1'b0;
      start_pending_q  <= 2'd0;
      feed_delay_q     <= 2'd0;
      array_a_q        <= 64'd0;
      array_b_q        <= 64'd0;

    end else begin

      if (req_i.aw_valid && resp_o.aw_ready) begin
        aw_addr_q    <= req_i.aw.addr;
        aw_pending_q <= 1'b1;
      end

      if (req_i.w_valid && resp_o.w_ready) begin
        w_data_q     <= req_i.w.data;
        w_pending_q  <= 1'b1;
      end

      if (aw_pending_q && w_pending_q && !b_valid_q) begin

        case (aw_addr_q[7:0])

          CTRL_OFFSET[7:0]: begin
            if (req_i.w.strb[0]) ctrl_q[7:0]   <= w_data_q[7:0];
            if (req_i.w.strb[1]) ctrl_q[15:8]  <= w_data_q[15:8];
            if (req_i.w.strb[2]) ctrl_q[23:16] <= w_data_q[23:16];
            if (req_i.w.strb[3]) ctrl_q[31:24] <= w_data_q[31:24];

            if (w_data_q[0]) begin
              start_pending_q <= 2'd2;
              busy_q <= 1'b1;
              compute_cycle_q <= 4'd0;
              feed_delay_q <= 2'd1;
              array_a_q <= 64'd0;
              array_b_q <= 64'd0;
              status_q[0] <= 1'b0;
            end
          end

          default: begin
            if (aw_addr_q[7:0] >= A_STREAM_OFFSET[7:0] &&
                aw_addr_q[7:0] < (A_STREAM_OFFSET[7:0] + 8*8) &&
                aw_addr_q[1:0] == 2'b00) begin
              if (aw_addr_q[2])
                a_stream_q[(aw_addr_q[7:0] - A_STREAM_OFFSET[7:0]) >> 3][63:32] <=
                    w_data_q;
              else
                a_stream_q[(aw_addr_q[7:0] - A_STREAM_OFFSET[7:0]) >> 3][31:0] <=
                    w_data_q;
            end else if (aw_addr_q[7:0] >= B_STREAM_OFFSET[7:0] &&
                         aw_addr_q[7:0] < (B_STREAM_OFFSET[7:0] + 8*8) &&
                         aw_addr_q[1:0] == 2'b00) begin
              if (aw_addr_q[2])
                b_stream_q[(aw_addr_q[7:0] - B_STREAM_OFFSET[7:0]) >> 3][63:32] <=
                    w_data_q;
              else
                b_stream_q[(aw_addr_q[7:0] - B_STREAM_OFFSET[7:0]) >> 3][31:0] <=
                    w_data_q;
            end
          end

        endcase

        aw_pending_q <= 1'b0;
        w_pending_q  <= 1'b0;

        b_valid_q <= 1'b1;
      end

      if (b_valid_q && req_i.b_ready)
        b_valid_q <= 1'b0;

      if (start_pending_q != 2'd0) begin
        start_pending_q <= start_pending_q - 1'b1;
      end else if (busy_q) begin
        if (feed_delay_q != 2'd0) begin
          feed_delay_q <= feed_delay_q - 1'b1;
          array_a_q <= 64'd0;
          array_b_q <= 64'd0;
        end else if (compute_cycle_q == 5'd20) begin
          result_q <= systolic_result;
          status_q[0] <= 1'b1;
          busy_q <= 1'b0;
        end else if (compute_cycle_q < 5'd8) begin
          array_a_q <= a_stream_q[compute_cycle_q[2:0]];
          array_b_q <= b_stream_q[compute_cycle_q[2:0]];
          compute_cycle_q <= compute_cycle_q + 1'b1;
        end else begin
          array_a_q <= 64'd0;
          array_b_q <= 64'd0;
          compute_cycle_q <= compute_cycle_q + 1'b1;
        end
      end

      if (req_i.ar_valid && resp_o.ar_ready) begin

        case (req_i.ar.addr[7:0])

          8'h00:
            r_data_q <= ctrl_q;

          8'h04:
            r_data_q <= status_q;

          default: begin
            if (req_i.ar.addr[7:0] >= RES0_OFFSET[7:0] &&
                req_i.ar.addr[7:0] < (RES0_OFFSET[7:0] + 16*4)) begin
              int unsigned word_idx;
              word_idx = (req_i.ar.addr[7:0] - RES0_OFFSET[7:0]) >> 2;
              r_data_q <= result_q[32*word_idx +:32];
            end else begin
              r_data_q <= 32'h00000000;
            end
          end

        endcase

        r_valid_q <= 1'b1;

      end

      if (r_valid_q && req_i.r_ready)
        r_valid_q <= 1'b0;

    end
  end

endmodule
