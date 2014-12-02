`include "definitions.sv"

module hazard_unit (
    input  clk,
    input  jump_now,
		input  fd_pipeline_s  fd_pipeline_r,
		input  control_pipeline_s control_pipeline,
	  input  dx_pipeline_s  dx_pipeline_r,
    input  xm_pipeline_s xm_pipeline_r,
		input  mw_pipeline_s mw_pipeline_r,
    output logic bubble,
  	output logic [1:0] forwardA,
    output logic [1:0] forwardB
    );

//fwd from EX/MEM pipeline reg
always_comb
begin

//ForwardA = 10;
	if ( xm_pipeline_r.ctrl_signals.op_writes_rf_o && ( xm_pipeline_r.instruction.rd != 0 ) &&
		 ( xm_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rs_imm ))
			forwardA = 2'b10;

//fwd from MEM/WB pipeline reg
//ForwardA = 01;
	else if ( mw_pipeline_r.ctrl_signals.op_writes_rf_o && ( mw_pipeline_r.instruction.rd != 0 ) &&
         ~( mw_pipeline_r.ctrl_signals.op_writes_rf_o && ( xm_pipeline_r.instruction.rd != 0 ) &&
          ( xm_pipeline_r.instruction.rd === dx_pipeline_r.instruction.rs_imm ) ) &&
					( mw_pipeline_r.instruction.rd === dx_pipeline_r.instruction.rs_imm ) )
					forwardA = 2'b01;

	else forwardA = 2'b00;

//ForwardB = 10;
 	if ( xm_pipeline_r.ctrl_signals.op_writes_rf_o && ( xm_pipeline_r.instruction.rd != 0 ) &&
		 ( xm_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rd ))
				forwardB = 2'b10;

//ForwardB = 01;
	else if ( mw_pipeline_r.ctrl_signals.op_writes_rf_o && ( mw_pipeline_r.instruction.rd != 0 ) &&
         ~( xm_pipeline_r.ctrl_signals.op_writes_rf_o && ( xm_pipeline_r.instruction.rd != 0 ) &&
          ( xm_pipeline_r.instruction.rd === dx_pipeline_r.instruction.rd ) ) &&
					( mw_pipeline_r.instruction.rd === dx_pipeline_r.instruction.rd ) )
					forwardB =  2'b01;

	else forwardB = 2'b00;
	
end

//THE MYSTERIOUS GLUE THAT MAKES THE CPU WORK
assign bubble =  (dx_pipeline_r.ctrl_signals.is_load_op_o || dx_pipeline_r.ctrl_signals.is_store_op_o) && 
                 ((dx_pipeline_r.instruction.rd == fd_pipeline_r.instruction.rs_imm) || 
                    (dx_pipeline_r.instruction.rd == fd_pipeline_r.instruction.rd) || 
                    control_pipeline.is_load_op_o || 
                    control_pipeline.is_store_op_o);

endmodule
