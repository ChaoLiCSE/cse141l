// Bitcoin Mining Testbench
// Rich Park, Moein Khazraee
// Jan. 2014

`include "definitions.sv"

// Comment out this line to remove disassembly support
// You will need to do this when you run a gate-level i.e. timing simulation in ModelSim

//`define DISASSEMBLE

`define half_period 1.5
//`timescale 100 ns / 1 ns

// TODO: Edit the file names below to match your Assembler output files.
// read from assembled files and store in buffers
`define hex_i_file "../../assembler/lab2/src/miner_i.hex"
`define hex_r_file "../../assembler/lab2/src/miner_r.hex"
`define hex_d_file "../../assembler/lab2/src/miner_d.hex"

module miner_tb();

bit clk, reset, reset_r;
integer i;

// 5 is the op-code size
localparam instr_length_p = rd_size_gp + rs_imm_size_gp + 5; 
localparam instr_buffer_size_p = 1024;
localparam data_buffer_size_p = 1024;
localparam reg_packet_width_p = 40;

reg [instr_length_p-1:0] ins_packet [instr_buffer_size_p-1:0];
reg [31:0] data_packet [data_buffer_size_p-1:0];
reg [reg_packet_width_p-1:0] reg_packet [(2**rs_imm_size_gp)-1:0];

instruction_s instruct_t;

// Data memory connected to core
mem_in_s mem_in2,mem_in1, mem_in;
logic [$bits(mem_in_s)-1:0] mem_in1_flat, mem_in_flat; 
assign mem_in1 = mem_in1_flat;
assign mem_in_flat = mem_in;

mem_out_s mem_out;
logic [$bits(mem_out_s)-1:0] mem_out_flat;
assign mem_out = mem_out_flat;
bit select;
logic [31:0] data_mem_addr,data_mem_addr1,data_mem_addr2;
data_mem datamem_1
                (.clk(clk)
                ,.reset(reset_r)
                ,.port_flat_i(mem_in_flat) 
                ,.addr(data_mem_addr)
                ,.port_flat_o(mem_out_flat)
                );

// Main core
net_packet_s core_in, core_out, packet;
logic [$bits(net_packet_s)-1:0] core_in_flat, core_out_flat;
assign core_in_flat = core_in;
assign core_out = core_out_flat;

logic [mask_length_gp-1:0] barrier_OR;
debug_s debug;
logic exception;

logic [31:0] cycle_counter_r;

always_ff @(posedge clk)
  if (!reset)
    cycle_counter_r <= 32'b0;
  else
    cycle_counter_r <= cycle_counter_r + 1'b1;
   
   core_flattened dut
                 (.clk(clk)
                  ,.reset(reset_r)
                  ,.net_packet_flat_i(core_in_flat)
                  ,.net_packet_flat_o(core_out_flat)
                  ,.from_mem_flat_i(mem_out_flat)
                  ,.to_mem_flat_o(mem_in1_flat)
                  ,.barrier_o(barrier_OR)
                  ,.exception_o(exception)
                  ,.debug_flat_o(debug)
                  ,.data_mem_addr(data_mem_addr1)
                  );

// To select between core or test bench data and address for the data memory
assign mem_in        = select ? mem_in1        : mem_in2;
assign data_mem_addr = select ? data_mem_addr1 : data_mem_addr2;
// ----------------------------------------------------------------
   
   // this version of readmemh checks for errors
`define assert_readmemh(fileName, destination)                          \
       do                                                               \
         begin                                                          \
            automatic integer fileid = $fopen(fileName,"r");            \
             if (fileid == 0)                                           \
                begin                                                   \
                  $display("\n#######\n####### ");                      \
                  $display("Can't open file %s", fileName);             \
                  $display("#######\n#######\n ");                      \
                  $stop;                                                \
                end                                                     \
             else                                                       \
               begin                                                    \
                  $fclose(fileid);                                      \
                  $readmemh(fileName, destination);                     \
                  if (destination[0] === 'x)                            \
                    begin                                               \
                       $display("\nFilename %s read X's; stopping.\n", fileName); \
                         $stop;                                         \
                    end                                                 \
               end                                                      \
          end while (0)


  initial begin
  typedef enum logic [2:0] {
      IDLE,
      LDWORK,
      LDNONCE,
      DONE
      } command_state_e;

  //BTC work 
  int work2 [3];
  int midstate [8];
  logic [32:0] nonce;

  command_state_e command;
  `assert_readmemh (`hex_i_file, ins_packet);
  `assert_readmemh (`hex_d_file, data_packet);
  `assert_readmemh (`hex_r_file, reg_packet);

  // The signals are initialized and the core is reset
  packet = 0;
  reset = 1'b1;
  clk   = 1'b0;

  reset=1'b0; 
  @ (negedge clk)
  @ (negedge clk)
    reset = 1'b1;
  
  // Initialize the data memory, by sending each data as a store
  select = 1'b0;
  mem_in2.valid = 1'b1;
  mem_in2.yumi  = 1'b1;
  mem_in2.byte_not_word = 1'b0;
  mem_in2.wen = 1'b1;
  for(i=0;i<data_buffer_size_p;i=i+1)
    begin
      @ (negedge clk)
      @ (negedge clk)
      data_mem_addr2 = i*4;
      mem_in2.write_data = data_packet[i];
    end
                                                
  @ (negedge clk)
  mem_in2.valid = 1'b0;
  mem_in2.yumi  = 1'b0;
  @ (negedge clk)
  
  // Connect the core to the memory
  select = 1'b1;
  
  // Insert instructions: Read from the buffers 
  // and send the instructions as packets to the core
  for(i=0;i<instr_buffer_size_p;i=i+1)
    begin
      instruct_t='{opcode: ins_packet[i][15:11]
                  ,rd:     ins_packet[i][10:6]
                  ,rs_imm: ins_packet[i][5:0]};
      
      @ (negedge clk)
        packet  ='{ID:       10'b0000000001
                  ,net_op:   INSTR
                  ,reserved: 5'b0
                  ,net_data: {{(16){1'b0}},{instruct_t}} 
                  ,net_addr: i};
    end
  
  // Insert register values: Read from the buffers 
  // and send the register values as packets to the core
  for(i=0;i<(2**rs_imm_size_gp);i=i+1)
    begin
      @ (negedge clk)
        packet  ='{ID:       10'b0000000001
                  ,net_op:   REG
                  ,reserved: 5'b0
                  ,net_data: reg_packet[i][31:0]
                  ,net_addr: reg_packet[i][37:32]};
    end
  
  cycle_counter_r = 1'b0;

  $display("[*] Finished Initializing Core and Memory");
  // Initialize the Barrier mask to 111
  @ (negedge clk)
    packet  ='{ID:       10'b0000000001
              ,net_op:   BAR
              ,reserved: 5'b0
              ,net_data: 32'd7
              ,net_addr:  10'd24}; 

// Sending the bitcoin miner work and midstate
   midstate = {32'h56f6950a, 32'h86a3a529, 32'h7961969c, 32'h7bfdb28c, 32'h54c9af5a, 32'h951237b8, 32'h7979d96f, 32'hc01823e1};
   work2 = {32'ha24c2683, 32'hcf1beb52, 32'h2cf50119};


  for(i = 1; i < 10; i = i + 1) begin
       @ (negedge clk)
         packet  ='{ID:       10'b0000000001
                   ,net_op:   REG
                   ,reserved: 5'b0
                   ,net_data: midstate[i - 1]
                   ,net_addr:  i}; 
  end
  for(i = 0; i < 3; i = i + 1) begin
       @ (negedge clk)
         packet  ='{ID:       10'b0000000001
                   ,net_op:   REG
                   ,reserved: 5'b0
                   ,net_data: work2[i]
                   ,net_addr:  i + 9}; 
  end
// Send COMMAND 1
   command = LDWORK;

   @ (negedge clk)
     packet  ='{ID:       10'b0000000001
               ,net_op:   REG
               ,reserved: 5'b0
               ,net_data: 32'd1
               ,net_addr:  10'd20}; 

  // Set the PC to zero ; Set Barrier Bits to 010
  @ (negedge clk)
    packet  ='{ID:       10'b0000000001
              ,net_op:   PC
              ,reserved: 5'b0
              ,net_data: 32'h2 
              ,net_addr:  10'd0 }; 

  
  // No more network interfere
  @ (negedge clk)
    packet  ='{ID:       10'b0000000001
              ,net_op:   NULL
              ,reserved: 5'b0
              ,net_data: 32'hFFFFFFFE
              ,net_addr:  10'd24};
  
  $display ("-------- START MINING ---------");
  nonce = 0;
  while (1) begin
     // Set initial nonce to 0
      @ (negedge clk)
      if (barrier_OR == 3'b000) begin
          if (command == LDWORK) begin
              $display("[*] Finished loading Block Header and Midstate");
              $display("[*] Initializing Miner with Nonce = 0x%h", nonce);
              @ (negedge clk)
              @ (negedge clk)
              command = LDNONCE;
              packet  ='{ID:       10'b0000000001
                       ,net_op:   REG
                       ,reserved: 5'b0
                       ,net_data: nonce
                       ,net_addr:  10'd1}; 
              @ (negedge clk)
             packet  ='{ID:       10'b0000000001
                       ,net_op:   REG
                       ,reserved: 5'b0
                       ,net_data: 32'd2
                       ,net_addr:  10'd20}; 
              @ (negedge clk)
             packet  ='{ID:       10'b0000000001
                       ,net_op:   PC
                       ,reserved: 5'b0
                       ,net_data: 32'h2 
                       ,net_addr:  10'd0 }; 
             // No more network interfere
             @ (negedge clk)
               packet  ='{ID:       10'b0000000001
                         ,net_op:   NULL
                         ,reserved: 5'b0
                         ,net_data: 32'hFFFFFFFE
                         ,net_addr:  10'd24};
             
          end else if (command == LDNONCE) begin
              nonce = nonce + 1;
              $display("[*] Trying a new Nonce = 0x%h", nonce);
              @ (negedge clk)
              @ (negedge clk)
              command = LDNONCE;
              packet  ='{ID:       10'b0000000001
                       ,net_op:   REG
                       ,reserved: 5'b0
                       ,net_data: nonce
                       ,net_addr:  10'd1}; 
              @ (negedge clk)
             packet  ='{ID:       10'b0000000001
                       ,net_op:   REG
                       ,reserved: 5'b0
                       ,net_data: 32'd2
                       ,net_addr:  10'd20}; 
              @ (negedge clk)
             packet  ='{ID:       10'b0000000001
                       ,net_op:   PC
                       ,reserved: 5'b0
                       ,net_data: 32'h2 
                       ,net_addr:  10'd0 }; 
             // No more network interfere
             @ (negedge clk)
               packet  ='{ID:       10'b0000000001
                         ,net_op:   NULL
                         ,reserved: 5'b0
                         ,net_data: 32'hFFFFFFFE
                         ,net_addr:  10'd24};
          end

      end else if (barrier_OR == 3'b001) begin
              $display("[*] BTC Found!");
              @ (negedge clk)
              @ (negedge clk)
              command = DONE;
             packet  ='{ID:       10'b0000000001
                       ,net_op:   REG
                       ,reserved: 5'b0
                       ,net_data: 32'd3
                       ,net_addr:  10'd20}; 
              @ (negedge clk)
            packet  ='{ID:       10'b0000000001
                      ,net_op:   PC
                      ,reserved: 5'b0
                      ,net_data: 32'h2 
                      ,net_addr:  10'd0 }; 
             // No more network interfere
             @ (negedge clk)
               packet  ='{ID:       10'b0000000001
                         ,net_op:   NULL
                         ,reserved: 5'b0
                         ,net_data: 32'hFFFFFFFE
                         ,net_addr:  10'd24};
      end
  end
end

`ifdef DISASSEMBLE
`include "disassemble.v"
`endif

// Clock generator
always 
    // Toggle clock every 1 ticks
    #`half_period clk = ~clk;

   logic pass_fail_code_done;
   logic stop_simulator;

always @ (negedge clk)
  begin
     pass_fail_code_done = 1;
     stop_simulator = 0;

     if (mem_out.valid === 1)
       begin
          unique case (data_mem_addr1)
            32'hDEAD_DEAD:
              begin
                 $write("FAIL");
                 stop_simulator = 1;
              end
            32'h600D_BEEF:
              begin
                 $write("DONE");
                 stop_simulator = 1;
              end
            32'hC0DE_C0DE:
              $write("CODE");

            32'hC0FF_EEEE:
              $write("PASS");
            default:
              pass_fail_code_done = 0;
          endcase // unique case (data_mem_addr1)

          if (pass_fail_code_done == 1)
            $display(": 0x%8.8x %10.10d (CYCLE 0x%x %10d)"
                     ,mem_in.write_data
                     ,mem_in.write_data
                     ,cycle_counter_r
                     ,cycle_counter_r
                     );

          if (stop_simulator)
            $stop;
       end // if (mem_out.valid)
  end

// The packets become available to the core at positive edge of the clock, to be synchronous 
always_ff @ (posedge clk)
  begin
    reset_r <= reset;
    core_in <= packet;
  end

//network_packet_s_logger #(.verbosity_p(0))
//   np_log (
//           .clk(clk)
//           , .reset(reset)
//           , .net_packet_i(core_in)
//           , .cycle_counter_i(cycle_counter_r)
//           , .barrier_OR_i(barrier_OR)
//           );
endmodule
