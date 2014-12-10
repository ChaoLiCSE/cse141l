// A register file with asynchronous read and synchronous write
module reg_file #(parameter addr_width_p = 6)
                (input clk
                ,input [addr_width_p-1:0] rs_addr_i
                ,input [addr_width_p-1:0] rd_addr_i
                ,input [addr_width_p-1:0] write_addr_i
                ,input wen_i
                ,input  logic [31:0] write_data_i
                ,output logic [31:0] rs_val_o
                ,output logic [31:0] rd_val_o
                );

logic [31:0] rf [2**addr_width_p-1:0];

assign rs_val_o = rf [rs_addr_i];
assign rd_val_o = rf [rd_addr_i];

always_ff @ (negedge clk)
  begin
    if (wen_i)
      rf [write_addr_i] <= write_data_i;
  end

endmodule
