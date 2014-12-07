`include "definitions.sv"

module core #(parameter imem_addr_width_p=10
                       ,net_ID_p = 10'b0000000001)
             (input  clk
             ,input  reset
             ,input  net_packet_s net_packet_i
             ,input  mem_out_s from_mem_i

             ,output net_packet_s net_packet_o
             ,output mem_in_s  to_mem_o
             ,output logic [mask_length_gp-1:0] barrier_o
             ,output logic                      exception_o
             ,output debug_s                    debug_o
             ,output logic [31:0]               data_mem_addr
             );

//---- Addresses and Data ----//
// Ins. memory address signals
logic [imem_addr_width_p-1:0] PC_r, PC_n,
                              pc_plus1, imem_addr,
                              imm_jump_add;
// Ins. memory output
instruction_s instruction, imem_out, instruction_r;

// Result of ALU, Register file outputs, Data memory output data
logic [31:0] alu_result, rs_val_or_zero, rd_val_or_zero, rs_val, rd_val;

// Reg. File address
logic [($bits(instruction.rs_imm))-1:0] rd_addr;

// Data for Reg. File signals
logic [31:0] rf_wd;

//---- Control signals ----//
// ALU output to determine whether to jump or not
logic jump_now;

// controller output signals
logic valid_to_mem_c, PC_wen_r, PC_wen;

// Handshake protocol signals for memory
logic yumi_to_mem_c;

// Final signals after network interfere
logic imem_wen, rf_wen;

// Network operation signals
logic net_ID_match,      net_PC_write_cmd,  net_imem_write_cmd,
      net_reg_write_cmd, net_bar_write_cmd, net_PC_write_cmd_IDLE;

// Memory stages and stall signals
logic [1:0] mem_stage_r, mem_stage_n;
logic stall, stall_non_mem;

// Exception signal
logic exception_n;

// State machine signals
state_e state_r,state_n;

//---- network and barrier signals ----//
instruction_s net_instruction;
logic [mask_length_gp-1:0] barrier_r,      barrier_n,
                           barrier_mask_r, barrier_mask_n;
// Suppress warnings
assign net_packet_o = net_packet_i;

// DEBUG Struct
assign debug_o = {PC_r, instruction, state_r, barrier_mask_r, barrier_r};

//-----------------------------------------------------------------------------
// Control Signals
//-----------------------------------------------------------------------------
control_pipeline_s control_pipeline;
logic is_load_op_c, op_writes_rf_c, is_store_op_c, is_mem_op_c, is_byte_op_c;

//-----------------------------------------------------------------------------
// Forwarding Control
//-----------------------------------------------------------------------------
logic bubble;
logic [1:0] forwardA;
logic [1:0] forwardB;

//-----------------------------------------------------------------------------
// Pipeline Registers
//-----------------------------------------------------------------------------
fd_pipeline_s fd_pipeline_n, fd_pipeline_r;
dx_pipeline_s dx_pipeline_n, dx_pipeline_r;
xm_pipeline_s xm_pipeline_n, xm_pipeline_r;
mw_pipeline_s mw_pipeline_n, mw_pipeline_r;

always_ff @(posedge clk)
   begin
      if(!reset)
         begin
            fd_pipeline_r <= 0;
            dx_pipeline_r <= 0;
            xm_pipeline_r <= 0;
            mw_pipeline_r <= 0;
         end
      else
         begin
			   if(bubble) // stalling for lw instruction
               begin
                  fd_pipeline_r <= fd_pipeline_r;
                  dx_pipeline_r <= 0;
                  xm_pipeline_r <= xm_pipeline_n;
                  mw_pipeline_r <= mw_pipeline_n;
               end
            else if (PC_wen)
               begin
               if ( net_PC_write_cmd_IDLE )
                     begin // reset pipeline for new nonce
                        fd_pipeline_r <= 0;
                        dx_pipeline_r <= 0;
                        xm_pipeline_r <= 0;
                        mw_pipeline_r <= 0;
                     end
                  else if (jump_now) // conditional jumps
                     begin
                        // flush the two fetched instructions
                        fd_pipeline_r <= 0;
                        dx_pipeline_r <= 0;
                        // finish the previous two instructions
                        xm_pipeline_r <= xm_pipeline_n;
                        mw_pipeline_r <= mw_pipeline_n;
                     end
                  else
                     begin // normal pipeline forwarding
                        fd_pipeline_r <= fd_pipeline_n;
                        dx_pipeline_r <= dx_pipeline_n;
                        xm_pipeline_r <= xm_pipeline_n;
                        mw_pipeline_r <= mw_pipeline_n;
                     end
               end

         end
   end
   
//-----------------------------------------------------------------------------
// IF Stage
//-----------------------------------------------------------------------------
// Selection between network and core for instruction address
assign imem_addr = (net_imem_write_cmd) ? net_packet_i.net_addr : PC_n;

// Instruction memory
instr_mem #(.addr_width_p(imem_addr_width_p)) imem
           (.clk(clk)
           ,.addr_i(imem_addr)
           ,.instruction_i(net_instruction)
           ,.wen_i(imem_wen)
           ,.instruction_o(imem_out)
           );

// Since imem has one cycle delay and we send next cycle's address, PC_n,
// if the PC is not written, the instruction must not change
assign instruction = (PC_wen_r) ? imem_out : instruction_r;
           
// Determine next PC
assign pc_plus1     = PC_r + 1'b1;
assign imm_jump_add = $signed(dx_pipeline_r.instruction.rs_imm)  + $signed(dx_pipeline_r.pc);

// Next pc is based on network or the instruction
always_comb
  begin
    PC_n = pc_plus1;
    if (net_PC_write_cmd_IDLE)
      PC_n = net_packet_i.net_addr;
    else
      unique casez (dx_pipeline_r.instruction)
        `kJALR:
          PC_n = alu_result[0+:imem_addr_width_p];

        `kBNEQZ,`kBEQZ,`kBLTZ,`kBGTZ:
          if (jump_now)
            PC_n = imm_jump_add;

        default: begin end
      endcase
  end

  
assign PC_wen = (net_PC_write_cmd_IDLE || ~stall);

always_ff @(posedge clk)
   begin
      if(!reset)
         begin
            PC_r           <= 0;
            PC_wen_r       <= 0;
            instruction_r  <= 0;
         end
         begin
            if(PC_wen)
               PC_r        <= PC_n;
                 
            instruction_r  <= instruction;
            PC_wen_r       <= PC_wen;
         end
   end


//*****************************************************************************
// IF/ID Pipeline
//****************************************************************************
assign fd_pipeline_n.instruction = instruction;
assign fd_pipeline_n.pc          = PC_r;
                                                 
//-----------------------------------------------------------------------------
// ID Stage
//-----------------------------------------------------------------------------

// Decode module
cl_decode decode (.instruction_i(fd_pipeline_r.instruction)
                  ,.is_load_op_o(is_load_op_c)
                  ,.op_writes_rf_o(op_writes_rf_c)
                  ,.is_store_op_o(is_store_op_c)
                  ,.is_mem_op_o(is_mem_op_c)
                  ,.is_byte_op_o(is_byte_op_c)
                  );

//*****************************************************************************
//* Pipeline Control Signals
//****************************************************************************
assign control_pipeline.is_load_op_o   = is_load_op_c;
assign control_pipeline.op_writes_rf_o = op_writes_rf_c;
assign control_pipeline.is_store_op_o  = is_store_op_c;
assign control_pipeline.is_mem_op_o    = is_mem_op_c;
assign control_pipeline.is_byte_op_o   = is_byte_op_c;

// Register write could be from network or the controller
assign rf_wen = net_reg_write_cmd || (mw_pipeline_r.control.op_writes_rf_o && ~stall) || bubble;

// Selection between network and address included in the instruction which is executed
// Address for Reg. File is shorter than address of Ins. memory in network data
// Since network can write into immediate registers, the address is wider
// but for the destination register in an instruction the extra bits must be zero
assign rd_addr = (net_reg_write_cmd)
                 ? (net_packet_i.net_addr [0+:($bits(mw_pipeline_r.instruction.rs_imm))])
                 : ({{($bits(mw_pipeline_r.instruction.rs_imm)-$bits(mw_pipeline_r.instruction.rd)){1'b0}}
                    ,{mw_pipeline_r.instruction.rd}});

// Register file
reg_file #(.addr_width_p($bits(fd_pipeline_r.instruction.rs_imm))) rf
          (.clk(clk)
          ,.rs_addr_i(fd_pipeline_r.instruction.rs_imm)
          ,.rd_addr_i({{($bits(fd_pipeline_r.instruction.rs_imm)-$bits(fd_pipeline_r.instruction.rd)){1'b0}},{fd_pipeline_r.instruction.rd}})
          ,.write_addr_i(rd_addr)
          ,.wen_i(rf_wen)
          ,.write_data_i(rf_wd) 
          ,.rs_val_o(rs_val)
          ,.rd_val_o(rd_val)
          );

//*****************************************************************************
//* ID/EX Pipeline
//*****************************************************************************
assign dx_pipeline_n.instruction = fd_pipeline_r.instruction;
assign dx_pipeline_n.control     = control_pipeline;
assign dx_pipeline_n.pc          = fd_pipeline_r.pc;
assign dx_pipeline_n.rs_val      = rs_val;
assign dx_pipeline_n.rd_val      = rd_val;

//-----------------------------------------------------------------------------
// EX Stage
//-----------------------------------------------------------------------------

always_comb
   begin
      if(forwardA == 2'b10)
         rs_val_or_zero = xm_pipeline_r.alu_result;
		else if(forwardA == 2'b01)
         rs_val_or_zero = rf_wd;
		else
         rs_val_or_zero = (dx_pipeline_r.instruction.rs_imm) ? dx_pipeline_r.rs_val : 32'b0;
	
      if(forwardB == 2'b10)
         rd_val_or_zero = xm_pipeline_r.alu_result;
		else if(forwardB == 2'b01)
         rd_val_or_zero = rf_wd;
      else
         rd_val_or_zero = (dx_pipeline_r.instruction.rd) ? dx_pipeline_r.rd_val : 32'b0;
   end

// ALU
alu alu_1 (.rd_i(rd_val_or_zero)
          ,.rs_i(rs_val_or_zero)
          ,.op_i(dx_pipeline_r.instruction)
          ,.result_o(alu_result)
          ,.jump_now_o(jump_now)
          );
          
          
          
//*****************************************************************************
//* ID/EX Pipeline
//*****************************************************************************
assign xm_pipeline_n.instruction = dx_pipeline_r.instruction;
assign xm_pipeline_n.pc          = dx_pipeline_r.pc;
assign xm_pipeline_n.rs_val      = rs_val_or_zero;
assign xm_pipeline_n.rd_val      = rd_val_or_zero;
assign xm_pipeline_n.control     = dx_pipeline_r.control;
assign xm_pipeline_n.alu_result  = alu_result;

//-----------------------------------------------------------------------------
// MA Stage
//----------------------------------------------------------------------------- 

// Data_mem
assign data_mem_addr = xm_pipeline_r.alu_result;

// Launch LD/ST
assign valid_to_mem_c = xm_pipeline_r.control.is_mem_op_o & (mem_stage_r < 2'b10);

assign to_mem_o = '{write_data    : xm_pipeline_r.rs_val
                   ,valid         : valid_to_mem_c
                   ,wen           : xm_pipeline_r.control.is_store_op_o
                   ,byte_not_word : xm_pipeline_r.control.is_byte_op_o
                   ,yumi          : yumi_to_mem_c
                   };

 always_comb
  begin
    yumi_to_mem_c = 1'b0;
    mem_stage_n   = mem_stage_r;

    if(valid_to_mem_c)
        mem_stage_n   = 2'b01;

    if(from_mem_i.yumi)
        mem_stage_n   = 2'b10;

    // If we can commit the LD/ST this cycle, the acknowledge dmem's response
    if(from_mem_i.valid & ~stall_non_mem)
      begin
        mem_stage_n   = 2'b00;
        yumi_to_mem_c = 1'b1;
      end
  end
                  
//*****************************************************************************
//* MA/WB Pipeline
//*****************************************************************************                        
assign mw_pipeline_n.instruction = xm_pipeline_r.instruction;
assign mw_pipeline_n.control     = xm_pipeline_r.control;
assign mw_pipeline_n.pc          = xm_pipeline_r.pc;
assign mw_pipeline_n.rs_val      = xm_pipeline_r.rs_val;
assign mw_pipeline_n.rd_val      = xm_pipeline_r.rd_val;
assign mw_pipeline_n.alu_result  = xm_pipeline_r.alu_result;
assign mw_pipeline_n.from_mem_i  = from_mem_i;     
             
//-----------------------------------------------------------------------------
// WB Stage
//----------------------------------------------------------------------------- 

// select the input data for Register file, from network, the PC_plus1 for JALR,
// Data Memory or ALU result
always_comb
  begin
    if (net_reg_write_cmd)
      rf_wd = net_packet_i.net_data;
    else if (mw_pipeline_r.instruction ==? `kJALR)
      rf_wd = mw_pipeline_r.pc + 1;
    else if (mw_pipeline_r.control.is_load_op_o)
      rf_wd = mw_pipeline_r.from_mem_i.read_data;
    else
      rf_wd = mw_pipeline_r.alu_result;
  end

always_ff @(posedge clk)
   if(!reset)
      mem_stage_r <= 2'b00;
   else
      mem_stage_r <= mem_stage_n;
  
//-----------------------------------------------------------------------------
// IDK WTF Stage
//-----------------------------------------------------------------------------  

// Sequential part, including PC, barrier, exception and state
always_ff @ (posedge clk)
  begin
    if (!reset)
      begin
        barrier_mask_r  <= {(mask_length_gp){1'b0}};
        barrier_r       <= {(mask_length_gp){1'b0}};
        state_r         <= IDLE;
        exception_o     <= 0;
      end
    else
      begin
        barrier_mask_r <= barrier_mask_n;
        barrier_r      <= barrier_n;
        state_r        <= state_n;
        exception_o    <= exception_n;
      end
  end

// State machine
cl_state_machine state_machine (.instruction_i(dx_pipeline_r.instruction)
                               ,.state_i(state_r)
                               ,.exception_i(exception_o)
                               ,.net_PC_write_cmd_IDLE_i(net_PC_write_cmd_IDLE)
                               ,.stall_i(stall)
                               ,.state_o(state_n)
                               );
  
  
  
//-----------------------------------------------------------------------------
// Hazard Detection Unit
//----------------------------------------------------------------------------- 
// stall and memory stages signals
// rf structural hazard and imem structural hazard (can't load next instruction)
assign stall_non_mem = (net_reg_write_cmd && mw_pipeline_r.control.op_writes_rf_o)
                    || (net_imem_write_cmd);
// Stall if LD/ST still active; or in non-RUN state
assign stall = stall_non_mem || (mem_stage_n != 0) || (state_r != RUN) || bubble;


// logic from page 314
always_comb
   begin
      bubble = 0;
      if((dx_pipeline_r.control.is_mem_op_o ) && 
         ((dx_pipeline_r.instruction.rd == fd_pipeline_r.instruction.rs_imm) || 
         (dx_pipeline_r.instruction.rd == fd_pipeline_r.instruction.rd)))
         bubble = 1;
   end

   
//-----------------------------------------------------------------------------
// Forwarding Unit
//----------------------------------------------------------------------------- 
// logic from the online slides (04_Elsevier_pipeline.ppt.pdf): slide 40

always_comb
   begin
     forwardA = 2'b00;
     forwardB = 2'b00;
     // mem hazard detection
     if (xm_pipeline_r.control.op_writes_rf_o == 1 && 
         xm_pipeline_r.instruction.rd != 0  &&
         xm_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rs_imm )
       forwardA = 2'b10;
     if (xm_pipeline_r.control.op_writes_rf_o == 1 && 
         xm_pipeline_r.instruction.rd != 0 &&
         xm_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rd)
       forwardB = 2'b10;

     //forward alu result from data memory or earlier alu result
     if (mw_pipeline_r.control.op_writes_rf_o == 1 && 
         mw_pipeline_r.instruction.rd != 0  &&
        !(xm_pipeline_r.control.op_writes_rf_o == 1 && 
          xm_pipeline_r.instruction.rd != 0 &&
          xm_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rs_imm) &&
         mw_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rs_imm)
       forwardA = 2'b01;
     if (mw_pipeline_r.control.op_writes_rf_o == 1 && 
         mw_pipeline_r.instruction.rd != 0 &&
        !(xm_pipeline_r.control.op_writes_rf_o == 1 && 
          xm_pipeline_r.instruction.rd != 0  &&
          xm_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rd) &&
         mw_pipeline_r.instruction.rd == dx_pipeline_r.instruction.rd)
       forwardB =  2'b01;
   end


//---- Datapath with network ----//
// Detect a valid packet for this core
assign net_ID_match = (net_packet_i.ID==net_ID_p);

// Network operation
assign net_PC_write_cmd      = (net_ID_match && (net_packet_i.net_op==PC));
assign net_imem_write_cmd    = (net_ID_match && (net_packet_i.net_op==INSTR));
assign net_reg_write_cmd     = (net_ID_match && (net_packet_i.net_op==REG));
assign net_bar_write_cmd     = (net_ID_match && (net_packet_i.net_op==BAR));
assign net_PC_write_cmd_IDLE = (net_PC_write_cmd && (state_r==IDLE));

// Barrier final result, in the barrier mask, 1 means not mask and 0 means mask
assign barrier_o = barrier_mask_r & barrier_r;

// The instruction write is just for network
assign imem_wen  = net_imem_write_cmd;

// Instructions are shorter than 32 bits of network data
assign net_instruction = net_packet_i.net_data [0+:($bits(instruction))];

// barrier_mask_n, which stores the mask for barrier signal
always_comb
  // Change PC packet
  if (net_bar_write_cmd && (state_r != ERR))
    barrier_mask_n = net_packet_i.net_data [0+:mask_length_gp];
  else
    barrier_mask_n = barrier_mask_r;

// barrier_n signal, which contains the barrier value
// it can be set by PC write network command if in IDLE
// or by an an BAR instruction that is committing
assign barrier_n = net_PC_write_cmd_IDLE
                   ? net_packet_i.net_data[0+:mask_length_gp]
                   : ((xm_pipeline_r.instruction==?`kBAR) & ~stall)
                     ? xm_pipeline_r.alu_result [0+:mask_length_gp]
                     : barrier_r;

// exception_n signal, which indicates an exception
// We cannot determine next state as ERR in WORK state, since the instruction
// must be completed, WORK state means start of any operation and in memory
// instructions which could take some cycles, it could mean wait for the
// response of the memory to acknowledge the command. So we signal that we received
// a wrong package, but do not stop the execution. Afterwards the exception_r
// register is used to avoid extra fetch after this instruction.
always_comb
  if ((state_r==ERR) || (net_PC_write_cmd && (state_r!=IDLE)))
    exception_n = 1'b1;
  else
    exception_n = exception_o;

endmodule
