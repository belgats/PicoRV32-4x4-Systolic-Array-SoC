`timescale 1ns/1ps

module tb_soc;

  logic        clk_i;
  logic        rst_ni;
  logic        trap_o;
  logic        accel_start_o;
  logic [31:0] accel_debug_o;

  soc_top dut (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .trap_o         (trap_o),
    .accel_start_o  (accel_start_o),
    .accel_debug_o  (accel_debug_o)
  );

  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  initial begin
    rst_ni = 1'b0;
    repeat (10) @(posedge clk_i);
    rst_ni = 1'b1;

    for (int cycle = 0; cycle < 100000; cycle++) begin
      @(posedge clk_i);

      if (trap_o === 1'b1) begin
        $display("FAIL: PicoRV32 trap asserted at cycle %0d", cycle);
        $fatal(1);
      end

      if (dut.accel.status_q[0] === 1'b1) begin
        int expected [0:15];
        expected[0]  = 90;
        expected[1]  = 100;
        expected[2]  = 110;
        expected[3]  = 120;
        expected[4]  = 202;
        expected[5]  = 228;
        expected[6]  = 254;
        expected[7]  = 280;
        expected[8]  = 314;
        expected[9]  = 356;
        expected[10] = 398;
        expected[11] = 440;
        expected[12] = 426;
        expected[13] = 484;
        expected[14] = 542;
        expected[15] = 600;

        if (accel_debug_o !== 32'h0000_0001) begin
          $display("FAIL: unexpected accelerator debug value %08x",
                   accel_debug_o);
          $fatal(1);
        end

        for (int result_idx = 0; result_idx < 16; result_idx++) begin
          if (dut.accel.result_q[result_idx*32 +: 32] !== expected[result_idx]) begin
            $display("FAIL: result[%0d] expected %0d got %0d",
                     result_idx,
                     expected[result_idx],
                     dut.accel.result_q[result_idx*32 +: 32]);
            for (int dump_idx = 0; dump_idx < 16; dump_idx++)
              $display("RESULT[%0d] = %0d",
                       dump_idx,
                       dut.accel.result_q[dump_idx*32 +: 32]);
            $fatal(1);
          end
        end

        $display("PASS: full 4x4 matrix result verified at cycle %0d",
                 cycle);
        $finish;
      end
    end

    $display("FAIL: timeout waiting for accelerator completion");
    $fatal(1);
  end

endmodule
