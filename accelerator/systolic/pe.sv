module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  logic                     clk,
    input  logic                     rst,

    input  logic                     clear_acc,

    input  logic                     valid_in,

    input  logic [DATA_WIDTH-1:0]    a_in,
    input  logic [DATA_WIDTH-1:0]    b_in,

    output logic [DATA_WIDTH-1:0]    a_out,
    output logic [DATA_WIDTH-1:0]    b_out,

    output logic [ACC_WIDTH-1:0]     acc_out,
    output logic                     valid_out
);

    always_ff @(posedge clk) begin

        if (rst) begin
            a_out     <= '0;
            b_out     <= '0;
            acc_out   <= '0;
            valid_out <= 1'b0;
        end

        else begin

            // Forward data to neighboring PEs
            a_out <= a_in;
            b_out <= b_in;

            // Propagate valid
            valid_out <= valid_in;

            // Clear partial sum
            if (clear_acc) begin
                acc_out <= '0;
            end

            // MAC
            else if (valid_in) begin
                acc_out <= acc_out + (a_in * b_in);
            end

        end
    end

endmodule