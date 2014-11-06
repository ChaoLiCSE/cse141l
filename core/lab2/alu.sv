//This is the ALU module of the core, op_code_e is defined in definitions.v file
`include "definitions.sv"

module alu (input  [31:0] rd_i 
           ,input  [31:0] rs_i 
           ,input  instruction_s op_i
           ,output logic [31:0] result_o
           ,output logic jump_now_o
);


logic [31:0] A;
logic [31:0] B;
logic [31:0] C;
logic [31:0] D;

always_comb
  begin
    jump_now_o = 1'bx;
    result_o   = 32'dx;
	 A		 		= 32'dx;
	 B				= 32'dx;
	 C				= 32'dx;
	 D				= 32'dx;
	 
    unique casez (op_i)
      `kADDU:  result_o   = rd_i +  rs_i;
      `kSUBU:  result_o   = rd_i -  rs_i;
      `kSLLV:  result_o   = rd_i << rs_i[4:0];
      `kSRAV:  result_o   = $signed (rd_i)   >>> rs_i[4:0];
      `kSRLV:  result_o   = $unsigned (rd_i) >>  rs_i[4:0]; 
      `kAND:   result_o   = rd_i & rs_i;
      `kOR:    result_o   = rd_i | rs_i;
      `kNOR:   result_o   = ~ (rd_i|rs_i);
      `kSLT:   result_o   = ($signed(rd_i)<$signed(rs_i))     ? 32'd1 : 32'd0;
      `kSLTU:  result_o   = ($unsigned(rd_i)<$unsigned(rs_i)) ? 32'd1 : 32'd0;
      `kBEQZ:  jump_now_o = (rd_i==32'd0)                     ? 1'b1  : 1'b0;
      `kBNEQZ: jump_now_o = (rd_i!=32'd0)                     ? 1'b1  : 1'b0;
      `kBGTZ:  jump_now_o = ($signed(rd_i)>$signed(32'd0))    ? 1'b1  : 1'b0;
      `kBLTZ:  jump_now_o = ($signed(rd_i)<$signed(32'd0))    ? 1'b1  : 1'b0;
      
      `kMOV, `kLW, `kLBU, `kJALR, `kBAR:   
               result_o   = rs_i;
      `kSW, `kSB:    
               result_o   = rd_i;
		
		
		// exclusive or
		`kXOR:	result_o	  = (rd_i | rs_i) & ~ (rd_i & rs_i);
		// rotate right
		`kROR:	result_o	  = (rd_i >> rs_i[4:0]) | (rd_i << 32'd32 - rs_i[4:0]);	
		// rotate left
		`kROL:	result_o   = (rd_i << rs_i[4:0]) | (rd_i >> 32'd32 - rs_i[4:0]);

		
		
		`kBS0: 
			begin
				A 	= (rs_i >> 2) | (rs_i << 30);
				B 	= (rs_i >> 13) | (rs_i << 19);
				C 	= (rs_i >> 22) | (rs_i << 10);
				D 	= (A | B) & ~(A & B);
				result_o = (D | C) & ~(D & C); 
			end
			
		`kBS1: 
			begin
				A 	= (rs_i >> 6) | (rs_i << 26);
				B 	= (rs_i >> 11) | (rs_i << 21);
				C 	= (rs_i >> 25) | (rs_i << 7);
				D 	= (A | B) & ~(A & B);
				result_o = (D | C) & ~(D & C); 
			end
		
		`kSS0: 
			begin
				A 	= (rs_i >> 7) | (rs_i << 25);
				B 	= (rs_i >> 18) | (rs_i << 14);
				C 	= rs_i >> 3;
				D 	= (A | B) & ~(A & B);
				result_o = (D | C) & ~(D & C); 
			end
		
		`kSS1: 
			begin
				A 	= (rs_i >> 17) | (rs_i << 15);
				B 	= (rs_i >> 19) | (rs_i << 13);
				C 	= rs_i >> 10;
				D 	= (A | B) & ~(A & B);
				result_o = (D | C) & ~(D & C); 
			end
		
		/*
		// big sigma 0
		`kBS0:	result_o 	= ((((((rs_i >> 2) | (rs_i << 30)) | ((rs_i >> 13) | (rs_i << 19))) & 
										(~(((rs_i >> 2) | (rs_i << 30)) & ((rs_i >> 13) | (rs_i << 19)))))) | ((rs_i >> 22) | (rs_i >> 10))) &
									  (~((((((rs_i >> 2) |(rs_i << 30)) | ((rs_i >> 13) | (rs_i << 19))) &
										  (~(((rs_i >> 2) |(rs_i << 30)) & ((rs_i >> 13) | (rs_i << 19)))))) & ((rs_i >> 22) | (rs_i >> 10)))); 
		
		
		// big sigma 1
		`kBS1:	result_o		= ((((((rs_i >> 6) | (rs_i << 30)) | ((rs_i >> 11) | (rs_i << 25))) &
										(~(((rs_i >> 6) | (rs_i << 30)) & ((rs_i >> 11) | (rs_i << 25))))) | ((rs_i >> 25) | (rs_i << 6))) & 
									  (~(((((rs_i >> 6) | (rs_i << 30)) | ((rs_i >> 11) | (rs_i << 25))) & 
										 (~(((rs_i >> 6) | (rs_i << 30)) & ((rs_i >> 11) | (rs_i << 25))))) & ((rs_i >> 25) | (rs_i << 6)))));
		
		// small sigma 0
		`kSS0:	result_o		= (((((rs_i >> 7) | (rs_i << 25)) | ((rs_i >> 18) | (rs_i << 14))) &
									  (~(((rs_i >> 7) | (rs_i << 25)) & ((rs_i >> 18) | (rs_i << 14))))) | ((rs_i >> 3))) &
									  (~(((((rs_i >> 7) | (rs_i << 25)) | ((rs_i >> 18) | (rs_i << 14))) &
										  (~((rs_i >> 7) | (rs_i << 25)) & ((rs_i >> 18) | (rs_i << 14)))) & ((rs_i >> 3))));
		
		// small sigma 1
		`kSS1:	result_o		= (((((rs_i >> 17) | (rs_i << 15)) | ((rs_i >> 19) | (rs_i << 13))) &
									  (~(((rs_i >> 17) | (rs_i << 15)) & ((rs_i >> 19) | (rs_i << 13))))) | ((rs_i >> 10))) &
									  (~(((((rs_i >> 17) | (rs_i << 15)) | ((rs_i >> 19) | (rs_i << 13))) & 
									    (~(((rs_i >> 17) | (rs_i << 15)) & ((rs_i >> 19) | (rs_i << 13))))) & ((rs_i >> 10))));
		
		*/
		//`kDONE:
      
      default: 
        begin 
          result_o   = 32'dX; 
          jump_now_o = 1'bX; 
        end
    endcase
  end

endmodule 
