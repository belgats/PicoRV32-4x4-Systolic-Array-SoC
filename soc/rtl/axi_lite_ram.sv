module axi_lite_ram #(
    parameter int WORDS = 16384,
    parameter string HEX_FILE = "firmware/firmware.hex",
    parameter type req_t  = logic,
    parameter type resp_t = logic
)(
    input  logic clk_i,
    input  logic rst_ni,

    input  req_t  req_i,
    output resp_t resp_o
);

    logic [31:0] mem [0:WORDS-1];

    logic [31:0] aw_addr_q;
    logic [31:0] w_data_q;
    logic [3:0]  w_strb_q;

    logic aw_pending_q;
    logic w_pending_q;

    logic b_valid_q;

    logic r_valid_q;
    logic [31:0] r_data_q;

    initial begin
        $display("========================================");
        $display("Loading firmware: %s", HEX_FILE);
        $display("RAM size: %0d bytes", WORDS * 4);
        $display("========================================");

        $readmemh(HEX_FILE, mem);
    end

    always_comb begin
        resp_o = '0;

        // Write address channel
        resp_o.aw_ready =
            !aw_pending_q &&
            !b_valid_q;

        // Write data channel
        resp_o.w_ready =
            !w_pending_q &&
            !b_valid_q;

        // Write response
        resp_o.b_valid = b_valid_q;
        resp_o.b.resp  = 2'b00;       // OKAY

        // Read address channel
        resp_o.ar_ready =
            !r_valid_q;

        // Read response
        resp_o.r_valid = r_valid_q;
        resp_o.r.data  = r_data_q;
        resp_o.r.resp  = 2'b00;       // OKAY
    end


    always_ff @(posedge clk_i or negedge rst_ni) begin

        if (!rst_ni) begin

            aw_addr_q    <= '0;
            w_data_q     <= '0;
            w_strb_q     <= '0;

            aw_pending_q <= 1'b0;
            w_pending_q  <= 1'b0;

            b_valid_q    <= 1'b0;

            r_valid_q    <= 1'b0;
            r_data_q     <= '0;

        end else begin

            // -----------------------------------------
            // Capture write address
            // -----------------------------------------

            if (req_i.aw_valid && resp_o.aw_ready) begin
                aw_addr_q    <= req_i.aw.addr;
                aw_pending_q <= 1'b1;
            end


            // -----------------------------------------
            // Capture write data
            // -----------------------------------------

            if (req_i.w_valid && resp_o.w_ready) begin
                w_data_q    <= req_i.w.data;
                w_strb_q    <= req_i.w.strb;
                w_pending_q <= 1'b1;
            end


            // -----------------------------------------
            // Execute write when AW + W are available
            // -----------------------------------------

            if (aw_pending_q &&
                w_pending_q &&
                !b_valid_q) begin

                if (w_strb_q[0])
                    mem[aw_addr_q[15:2]][7:0]
                        <= w_data_q[7:0];

                if (w_strb_q[1])
                    mem[aw_addr_q[15:2]][15:8]
                        <= w_data_q[15:8];

                if (w_strb_q[2])
                    mem[aw_addr_q[15:2]][23:16]
                        <= w_data_q[23:16];

                if (w_strb_q[3])
                    mem[aw_addr_q[15:2]][31:24]
                        <= w_data_q[31:24];

                $display(
                    "[%0t] RAM WRITE addr=%08x data=%08x",
                    $time,
                    aw_addr_q,
                    w_data_q
                );

                aw_pending_q <= 1'b0;
                w_pending_q  <= 1'b0;

                b_valid_q <= 1'b1;
            end


            // -----------------------------------------
            // Complete write response
            // -----------------------------------------

            if (b_valid_q && req_i.b_ready)
                b_valid_q <= 1'b0;


            // -----------------------------------------
            // Read request
            // -----------------------------------------

            if (req_i.ar_valid && resp_o.ar_ready) begin

                r_data_q <= mem[req_i.ar.addr[15:2]];

                r_valid_q <= 1'b1;

                $display(
                    "[%0t] RAM READ addr=%08x data=%08x",
                    $time,
                    req_i.ar.addr,
                    mem[req_i.ar.addr[15:2]]
                );
            end


            // -----------------------------------------
            // Complete read response
            // -----------------------------------------

            if (r_valid_q && req_i.r_ready)
                r_valid_q <= 1'b0;

        end
    end

endmodule