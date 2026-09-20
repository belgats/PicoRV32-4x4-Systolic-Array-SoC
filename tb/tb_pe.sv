module tb_pe;

    logic clk;
    logic rst;
    logic clear_acc;
    logic valid_in;

    logic [7:0] a_in;
    logic [7:0] b_in;

    logic [7:0] a_out;
    logic [7:0] b_out;

    logic [31:0] acc_out;
    logic valid_out;

    pe #(
        .DATA_WIDTH(8),
        .ACC_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst(rst),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .a_in(a_in),
        .b_in(b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc_out(acc_out),
        .valid_out(valid_out)
    );

    always #5 clk = ~clk;

    initial begin

        clk       = 0;
        rst       = 1;
        clear_acc = 0;
        valid_in  = 0;
        a_in      = 0;
        b_in      = 0;

        #20;

        rst = 0;

        // First MAC: 2 × 3
        @(negedge clk);
        valid_in = 1;
        a_in = 2;
        b_in = 3;

        // Second MAC: 4 × 5
        @(negedge clk);
        a_in = 4;
        b_in = 5;

        // Stop input
        @(negedge clk);
        valid_in = 0;

        #20;

        $display("Accumulator = %0d", acc_out);

        if (acc_out == 26)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");

        $finish;

    end

endmodule