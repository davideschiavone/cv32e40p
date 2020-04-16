import riscv_defines::*;

module riscv_pushpop_controller
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [3:0]  rcount_i,
  input  logic [4:0]  spimm16_i,
  input  logic        is_push_i,

  input  logic        id_valid_i,

  output logic [31:0] immediate_o,
  output logic        regfile_mem_we_o,
  output logic        regfile_alu_we_o,
  output logic        data_req_o,

  output logic [4:0]  reg_pushpop_o,

  input  logic        pushpop_ctrl_i,
  output logic        pushpop_done_o,
  input  logic        popret_in_id_i,
  output logic        popret_jump_o

);


 logic [31:0]  one_hot_mask, one_hot_mask_rev;
 logic [4:0]   ff1_result; // holds the index of the first '1'
 logic         ff_no_one;  // if no ones are found
 logic [4:0]   fl1_result; // holds the index of the last '1'
 logic  [4:0]  nplus3;
 logic  [31:0] offset, immediate_q;
 logic  [3:0]  mask, rcount_q, rcount_n;

 enum  logic [1:0] { IDLE, POPPUSH, ADD, JUMP } fsm_cs, fsm_ns;

 always_ff @(posedge clk or negedge rst_n) begin
   if(~rst_n) begin
     rcount_q    <= 0;
     fsm_cs      <= IDLE;
     immediate_q <= '0;
   end else begin
    if(id_valid_i && pushpop_ctrl_i) begin
       rcount_q    <= rcount_n;
       fsm_cs      <= fsm_ns;
       immediate_q <= immediate_o;
    end
   end
 end


  assign nplus3   = rcount_i + 3;

  always_comb
  begin

      regfile_mem_we_o            = 1'b0;
      regfile_alu_we_o            = 1'b0;
      offset                      = spimm16_i<<2 + (3 - nplus3[1:0]);
      immediate_o                 = 32'h4;
      data_req_o                  = pushpop_ctrl_i;
      rcount_n                    = rcount_q - 1;
      pushpop_done_o              = 1'b0;
      popret_jump_o               = 1'b0;
      mask                        = rcount_i;
      reg_pushpop_o               = fl1_result;

    unique case(fsm_cs)

      IDLE:
      begin

        /*

          find last 1 of one_hot_mask to generate the register to push/pop
          decrease mask
          loop until mask == 0

        */
        mask             = rcount_i;
        rcount_n         = rcount_i - 1;
        //                              sp-4*N: sp+4*(4*sp16imm + 3-((N+3) mod 4))
        offset           = is_push_i ? $signed(-rcount_i) :  spimm16_i<<2 + (3 - nplus3[1:0]);
        immediate_o      = offset<<2;
        regfile_mem_we_o = pushpop_ctrl_i;
        fsm_ns           = rcount_n > 0 ? POPPUSH : ADD;
      end

      POPPUSH:
      begin

        /*

          find last 1 of one_hot_mask to generate the register to push/pop
          decrease mask
          loop until mask == 0

        */
        mask                        = rcount_q;
        immediate_o                 = immediate_q + 4;
        regfile_mem_we_o            = 1'b1;
        fsm_ns                      = rcount_n > 0 ? POPPUSH : ADD;
      end

      ADD:
      begin

        /*

          find last 1 of one_hot_mask to generate the register to push/pop
          decrease mask
          loop until mask == 0

        */
        mask              = rcount_q;
        data_req_o        = 1'b0;
        //sp+16*(((N+3)/4)+sp16imm
        offset            = (nplus3[4:2] + spimm16_i);
        immediate_o       = offset<<4;
        regfile_alu_we_o  = 1'b1;
        pushpop_done_o    = !popret_in_id_i;
        fsm_ns            = popret_in_id_i ? JUMP : IDLE;
      end

      JUMP:
      begin

        mask              = rcount_q;
        data_req_o        = 1'b0;
        pushpop_done_o    = 1'b1;
        reg_pushpop_o     = 1;
        popret_jump_o     = 1'b1;
        fsm_ns            = IDLE;
      end
    endcase // fsm_cs
  end





  riscv_ff_one alu_ff_i
  (
    .in_i        ( one_hot_mask_rev   ),
    .first_one_o ( ff1_result         ),
    .no_ones_o   ( ff_no_one          )
  );

  assign fl1_result    = 5'd31 - ff1_result;


 generate
   genvar k;
   for(k = 0; k < 32; k++)
   begin
     assign one_hot_mask_rev[k] = one_hot_mask[31-k];
   end
 endgenerate

 always_comb
 begin

   one_hot_mask = '0;

  unique case(mask)

    1: begin
      one_hot_mask[1] = 1'b1;
    end
    2: begin
      one_hot_mask[1] = 1'b1;
      one_hot_mask[8] = 1'b1;
    end
    3: begin
      one_hot_mask[1] = 1'b1;
      one_hot_mask[8] = 1'b1;
      one_hot_mask[9] = 1'b1;
    end
    4: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
    end
    5: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
    end
    6: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
    end
    7: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
    end
    8: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
    end
    9: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
    end
    10: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
      one_hot_mask[24] = 1'b1;
    end
    11: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
      one_hot_mask[24] = 1'b1;
      one_hot_mask[25] = 1'b1;
    end
    12: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
      one_hot_mask[24] = 1'b1;
      one_hot_mask[25] = 1'b1;
      one_hot_mask[26] = 1'b1;
    end
    13: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
      one_hot_mask[24] = 1'b1;
      one_hot_mask[25] = 1'b1;
      one_hot_mask[26] = 1'b1;
      one_hot_mask[27] = 1'b1;
    end
    14: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
      one_hot_mask[24] = 1'b1;
      one_hot_mask[25] = 1'b1;
      one_hot_mask[26] = 1'b1;
      one_hot_mask[27] = 1'b1;
      one_hot_mask[10] = 1'b1;
    end
    15: begin
      one_hot_mask[1]  = 1'b1;
      one_hot_mask[8]  = 1'b1;
      one_hot_mask[9]  = 1'b1;
      one_hot_mask[18] = 1'b1;
      one_hot_mask[19] = 1'b1;
      one_hot_mask[20] = 1'b1;
      one_hot_mask[21] = 1'b1;
      one_hot_mask[22] = 1'b1;
      one_hot_mask[23] = 1'b1;
      one_hot_mask[24] = 1'b1;
      one_hot_mask[25] = 1'b1;
      one_hot_mask[26] = 1'b1;
      one_hot_mask[27] = 1'b1;
      one_hot_mask[10] = 1'b1;
      one_hot_mask[11] = 1'b1;
    end
    default: begin
      one_hot_mask = '0;
    end
    endcase
 end







endmodule
