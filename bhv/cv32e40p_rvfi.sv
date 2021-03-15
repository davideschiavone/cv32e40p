// Copyright (c) 2020 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0

// CV32E40P RVFI interface
// Contributor: Davide Schiavone <davide@openhwgroup.org>

module cv32e40p_rvfi import cv32e40p_pkg::*;
(
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic [31:0] hart_id_i,

  input  logic        irq_ack_i,
  input  logic        illegal_insn_id_i,
  input  logic        mret_insn_id_i,

  input  logic        instr_is_compressed_id_i,
  input  logic [15:0] instr_rdata_c_id_i,
  input  logic [31:0] instr_rdata_id_i,


  input  logic        instr_id_valid_i,
  input  logic        instr_id_is_decoding_i,

  input  logic [31:0] rdata_a_id_i,
  input  logic [4:0]  raddr_a_id_i,
  input  logic [31:0] rdata_b_id_i,
  input  logic [4:0]  raddr_b_id_i,
  input  logic [31:0] rdata_c_id_i,
  input  logic [4:0]  raddr_c_id_i,

  input  logic        rd1_we_id_i,
  input  logic [4:0]  rd1_addr_id_i,
  input  logic        rd2_we_id_i,
  input  logic [4:0]  rd2_addr_id_i,

  input  logic [31:0] pc_id_i,
  input  logic [31:0] pc_if_i,
  input  logic [31:0] jump_target_id_i,

  input  logic        pc_set_i,
  input  logic        is_jump_id_i,

  input  logic [1:0]  lsu_type_id_i,
  input  logic        lsu_we_id_i,
  input  logic        lsu_req_id_i,

  input  logic        instr_ex_ready_i,
  input  logic        instr_ex_valid_i,

  input  logic [31:0] rd1_wdata_ex_i,

  input  logic [31:0] branch_target_ex_i,
  input  logic        is_branch_ex_i,

  input  logic [31:0] lsu_addr_ex_i,
  input  logic [31:0] lsu_wdata_ex_i,
  input  logic        lsu_req_ex_i,
  input  logic        lsu_misagligned_ex_i,
  input  logic        lsu_is_misagligned_ex_i,

  input  logic        instr_wb_ready_i,
  input  logic [31:0] rd2_wdata_wb_i,

  input  logic [31:0] exception_target_wb_i,
  input  logic        is_exception_wb_i,


  input  logic [31:0] mepc_target_wb_i,
  input  logic        is_mret_wb_i,

  input  logic        is_debug_mode,

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
  output logic [RVFI_NRET-1:0]     rvfi_valid,
  output logic [RVFI_NRET*64-1:0]  rvfi_order,
  output logic [RVFI_NRET*32 -1:0] rvfi_insn,
  output logic [RVFI_NRET-1:0]     rvfi_trap,
  output logic [RVFI_NRET-1:0]     rvfi_halt,
  output logic [RVFI_NRET-1:0]     rvfi_intr,
  output logic [RVFI_NRET*2-1:0]   rvfi_mode,
  output logic [RVFI_NRET*2-1:0]   rvfi_ixl,

  output logic [RVFI_NRET*5-1:0]   rvfi_rs1_addr,
  output logic [RVFI_NRET*5-1:0]   rvfi_rs2_addr,
  output logic [RVFI_NRET*5-1:0]   rvfi_rs3_addr,
  output logic [RVFI_NRET*32-1:0]  rvfi_rs1_rdata,
  output logic [RVFI_NRET*32-1:0]  rvfi_rs2_rdata,
  output logic [RVFI_NRET*32-1:0]  rvfi_rs3_rdata,
  output logic [RVFI_NRET*5-1:0]   rvfi_rd1_addr,
  output logic [RVFI_NRET*32-1:0]  rvfi_rd1_wdata,
  output logic [RVFI_NRET*5-1:0]   rvfi_rd2_addr,
  output logic [RVFI_NRET*32-1:0]  rvfi_rd2_wdata,
  output logic [RVFI_NRET*32-1:0]  rvfi_pc_rdata,
  output logic [RVFI_NRET*32-1:0]  rvfi_pc_wdata,
  output logic [RVFI_NRET*32-1:0]  rvfi_mem_addr,
  output logic [RVFI_NRET*32/8-1:0]rvfi_mem_rmask,
  output logic [RVFI_NRET*32/8-1:0]rvfi_mem_wmask,
  output logic [RVFI_NRET*32-1:0]  rvfi_mem_rdata,
  output logic [RVFI_NRET*32-1:0]  rvfi_mem_wdata
);

  logic        rvfi_instr_new_wb;
  logic        rvfi_intr_q;
  logic        rvfi_set_trap_pc_d;
  logic        rvfi_set_trap_pc_q;
  logic [31:0] rvfi_insn_id;
  logic [4:0]  rvfi_rs1_addr_d;
  logic [4:0]  rvfi_rs2_addr_d;
  logic [4:0]  rvfi_rs3_addr_d;
  logic [31:0] rvfi_rs1_data_d;
  logic [31:0] rvfi_rs2_data_d;
  logic [31:0] rvfi_rs3_data_d;

  logic [4:0]  rvfi_rd1_addr_d;
  logic [4:0]  rvfi_rd2_addr_d;

  logic [31:0] rvfi_rd1_wdata_d;
  logic [31:0] rvfi_rd2_wdata_d;


  logic [3:0]  rvfi_mem_mask_int;
  logic [31:0] rvfi_mem_rdata_d;
  logic [31:0] rvfi_mem_wdata_d;
  logic [31:0] rvfi_mem_addr_d;

  // When writeback stage is present RVFI information is emitted when instruction is finished in
  // third stage but some information must be captured whilst the instruction is in the second
  // stage. Without writeback stage RVFI information is all emitted when instruction retires in
  // second stage. RVFI outputs are all straight from flops. So 2 stage pipeline requires a single
  // set of flops (instr_info => RVFI_out), 3 stage pipeline requires two sets (instr_info => wb
  // => RVFI_out)
  localparam int RVFI_STAGES = 3;

  logic        rvfi_stage_valid     [RVFI_STAGES][RVFI_NRET];
  logic [63:0] rvfi_stage_order     [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_insn      [RVFI_STAGES][RVFI_NRET];
  logic        rvfi_stage_trap      [RVFI_STAGES][RVFI_NRET];
  logic        rvfi_stage_halt      [RVFI_STAGES][RVFI_NRET];
  logic        rvfi_stage_intr      [RVFI_STAGES][RVFI_NRET];
  logic [ 4:0] rvfi_stage_rs1_addr  [RVFI_STAGES][RVFI_NRET];
  logic [ 4:0] rvfi_stage_rs2_addr  [RVFI_STAGES][RVFI_NRET];
  logic [ 4:0] rvfi_stage_rs3_addr  [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_rs1_rdata [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_rs2_rdata [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_rs3_rdata [RVFI_STAGES][RVFI_NRET];
  logic [ 4:0] rvfi_stage_rd1_addr  [RVFI_STAGES][RVFI_NRET];
  logic [ 4:0] rvfi_stage_rd2_addr  [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_rd1_wdata [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_rd2_wdata [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_pc_rdata  [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_pc_wdata  [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_mem_addr  [RVFI_STAGES][RVFI_NRET];
  logic [ 3:0] rvfi_stage_mem_rmask [RVFI_STAGES][RVFI_NRET];
  logic [ 3:0] rvfi_stage_mem_wmask [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_mem_rdata [RVFI_STAGES][RVFI_NRET];
  logic [31:0] rvfi_stage_mem_wdata [RVFI_STAGES][RVFI_NRET];

  logic  [RVFI_STAGES-1:0] data_req_q;
  logic  [RVFI_STAGES-1:0] mret_q;

  logic         data_misagligned_q;
  logic  [31:0] prev_pc_wdata0_q;
  logic  [31:0] prev_pc_wdata1_q;
  logic  [63:0] order0_q;
  logic  [63:0] order1_q;
  logic         valid0_q;
  logic         valid1_q;
  logic  [31:0] prev_pc_wdata_newst0;
  logic  [31:0] prev_pc_wdata_newst1;
  logic         intr1_d;
  logic         intr0_d;
  logic         intr1_valid_d;
  logic         intr0_valid_d;

  logic        instr_id_done;
  logic        instr_ex_done;
  logic        instr_wb_done;

  logic        ex_stage_ready_q;
  logic        ex_stage_valid_q;

  `include "cv32e40p_rvfi_trace.svh"


  //instructions retiring in the EX stage
  assign rvfi_valid     [0]         = rvfi_stage_valid     [RVFI_STAGES-2][0];
  assign rvfi_order     [63:0]      = rvfi_stage_order     [RVFI_STAGES-2][0];
  assign rvfi_insn      [31:0]      = rvfi_stage_insn      [RVFI_STAGES-2][0];
  assign rvfi_trap      [0]         = rvfi_stage_trap      [RVFI_STAGES-2][0];
  assign rvfi_halt      [0]         = rvfi_stage_halt      [RVFI_STAGES-2][0];
  assign rvfi_intr      [0]         = intr0_d;
  assign rvfi_mode      [1:0]       = 2'b11;
  assign rvfi_ixl       [1:0]       = 2'b01;
  assign rvfi_rs1_addr  [4:0]       = rvfi_stage_rs1_addr  [RVFI_STAGES-2][0];
  assign rvfi_rs2_addr  [4:0]       = rvfi_stage_rs2_addr  [RVFI_STAGES-2][0];
  assign rvfi_rs3_addr  [4:0]       = rvfi_stage_rs3_addr  [RVFI_STAGES-2][0];
  assign rvfi_rs1_rdata [31:0]      = rvfi_stage_rs1_rdata [RVFI_STAGES-2][0];
  assign rvfi_rs2_rdata [31:0]      = rvfi_stage_rs2_rdata [RVFI_STAGES-2][0];
  assign rvfi_rs3_rdata [31:0]      = rvfi_stage_rs3_rdata [RVFI_STAGES-2][0];
  assign rvfi_rd1_addr  [4:0]       = rvfi_stage_rd1_addr  [RVFI_STAGES-2][0];
  assign rvfi_rd2_addr  [4:0]       = rvfi_stage_rd2_addr  [RVFI_STAGES-2][0];
  assign rvfi_rd1_wdata [31:0]      = rvfi_stage_rd1_wdata [RVFI_STAGES-2][0];
  assign rvfi_rd2_wdata [31:0]      = rvfi_stage_rd2_wdata [RVFI_STAGES-2][0];
  assign rvfi_pc_rdata  [31:0]      = rvfi_stage_pc_rdata  [RVFI_STAGES-2][0];
  assign rvfi_pc_wdata  [31:0]      = rvfi_stage_pc_wdata  [RVFI_STAGES-2][0];
  assign rvfi_mem_addr  [31:0]      = rvfi_stage_mem_addr  [RVFI_STAGES-2][0];
  assign rvfi_mem_rmask [3:0]       = rvfi_stage_mem_rmask [RVFI_STAGES-2][0];
  assign rvfi_mem_wmask [3:0]       = rvfi_stage_mem_wmask [RVFI_STAGES-2][0];
  assign rvfi_mem_rdata [31:0]      = rvfi_stage_mem_rdata [RVFI_STAGES-2][0];
  assign rvfi_mem_wdata [31:0]      = rvfi_stage_mem_wdata [RVFI_STAGES-2][0];

  //instructions retiring in the WB stage
  assign rvfi_valid     [1]         = rvfi_stage_valid     [RVFI_STAGES-1][1];
  assign rvfi_order     [2*64-1:64] = rvfi_stage_order     [RVFI_STAGES-1][1];
  assign rvfi_insn      [2*32-1:32] = rvfi_stage_insn      [RVFI_STAGES-1][1];
  assign rvfi_trap      [1]         = rvfi_stage_trap      [RVFI_STAGES-1][1];
  assign rvfi_halt      [1]         = rvfi_stage_halt      [RVFI_STAGES-1][1];
  assign rvfi_intr      [1]         = intr1_d;;
  assign rvfi_mode      [3:2]       = 2'b11;
  assign rvfi_ixl       [3:2]       = 2'b01;
  assign rvfi_rs1_addr  [9:5]       = rvfi_stage_rs1_addr  [RVFI_STAGES-1][1];
  assign rvfi_rs2_addr  [9:5]       = rvfi_stage_rs2_addr  [RVFI_STAGES-1][1];
  assign rvfi_rs3_addr  [9:5]       = rvfi_stage_rs3_addr  [RVFI_STAGES-1][1];
  assign rvfi_rs1_rdata [2*32-1:32] = rvfi_stage_rs1_rdata [RVFI_STAGES-1][1];
  assign rvfi_rs2_rdata [2*32-1:32] = rvfi_stage_rs2_rdata [RVFI_STAGES-1][1];
  assign rvfi_rs3_rdata [2*32-1:32] = rvfi_stage_rs3_rdata [RVFI_STAGES-1][1];
  assign rvfi_rd1_addr  [9:5]       = rvfi_stage_rd1_addr  [RVFI_STAGES-1][1];
  assign rvfi_rd2_addr  [9:5]       = rvfi_stage_rd2_addr  [RVFI_STAGES-1][1];
  assign rvfi_rd1_wdata [2*32-1:32] = rvfi_stage_rd1_wdata [RVFI_STAGES-1][1];
  assign rvfi_rd2_wdata [2*32-1:32] = rvfi_stage_rd2_wdata [RVFI_STAGES-1][1];
  assign rvfi_pc_rdata  [2*32-1:32] = rvfi_stage_pc_rdata  [RVFI_STAGES-1][1];
  assign rvfi_pc_wdata  [2*32-1:32] = rvfi_stage_pc_wdata  [RVFI_STAGES-1][1];
  assign rvfi_mem_addr  [2*32-1:32] = rvfi_stage_mem_addr  [RVFI_STAGES-1][1];
  assign rvfi_mem_rmask [7:4]       = rvfi_stage_mem_rmask [RVFI_STAGES-1][1];
  assign rvfi_mem_wmask [7:4]       = rvfi_stage_mem_wmask [RVFI_STAGES-1][1];
  assign rvfi_mem_rdata [2*32-1:32] = rvfi_stage_mem_rdata [RVFI_STAGES-1][1];
  assign rvfi_mem_wdata [2*32-1:32] = rvfi_stage_mem_wdata [RVFI_STAGES-1][1];

  // An instruction in the ID stage is valid (instr_id_valid_i)
  // when it's not stalled by the EX stage
  // due to stalls in the EX stage, data hazards, or if it is not halted by the controller
  // as due interrupts, debug requests, illegal instructions, ebreaks and ecalls
  assign instr_id_done  = instr_id_valid_i & instr_id_is_decoding_i;

  assign instr_ex_done  = instr_ex_ready_i;

  assign instr_wb_done  = instr_wb_ready_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        ex_stage_ready_q   <= '0;
        ex_stage_valid_q   <= '0;
        data_misagligned_q <= '0;
        prev_pc_wdata0_q   <= '0;
        prev_pc_wdata1_q   <= '0;
        order0_q           <= '0;
        order1_q           <= '0;
        valid0_q           <= '0;
        valid1_q           <= '0;
      end else begin //1
        /*
            if instr_id_done is 1, it is implied that the EX stage is ready to accept a new instruction, thus ex_stage_ready_q <= 1
            if not, if instr_ex_done is 1 (i.e. ex_ready_i), we clean up the ex_stage_ready_q (if not id_done which has higher priority)
                    otherwise, if instr_ex_done is 0, we keep the old value to say that the instruction is valid but not complete or not valid
        */
        ex_stage_ready_q       <= instr_id_done ? 1'b1 : ( instr_ex_done == 1'b0 ? ex_stage_ready_q : 1'b0);

        ex_stage_valid_q       <= instr_id_done ? 1'b1 : ( instr_ex_valid_i == 1'b0 ? ex_stage_valid_q : 1'b0);

        if (instr_ex_done & data_req_q[0] & !lsu_misagligned_ex_i) begin
          data_misagligned_q <= lsu_is_misagligned_ex_i;
        end else begin //2
           if (instr_wb_done)
              if(data_misagligned_q)
                data_misagligned_q <= 1'b0;
        end //2

        if(rvfi_valid[1])
          {valid1_q, order1_q, prev_pc_wdata1_q} <= {rvfi_valid[1], rvfi_order[2*64-1:64], rvfi_pc_wdata[2*32-1:32]};
        if(rvfi_valid[0])
          {valid0_q, order0_q, prev_pc_wdata0_q} <= {rvfi_valid[0], rvfi_order[63:0], rvfi_pc_wdata[31:0]};

      end //1
    end //always_ff


    always_comb begin
      prev_pc_wdata_newst0 = '0;
      prev_pc_wdata_newst1 = '0;
      intr1_d              = 1'b0;
      intr0_d              = 1'b0;
      intr1_valid_d        = 1'b0;
      intr0_valid_d        = 1'b0;

      //find the newest
      if(rvfi_valid[1] ^ rvfi_valid[0]) begin

        if(!valid1_q & !valid0_q) begin
          intr1_d              = 1'b0;
          intr0_d              = 1'b0;
        end else begin
          if(valid1_q & !valid0_q) begin
            prev_pc_wdata_newst0 = prev_pc_wdata1_q;
            if(rvfi_valid[1])
                intr0_valid_d  = rvfi_order[2*64-1:64] - order1_q == 1;
            else
                intr0_valid_d  = rvfi_order[63:0] - order1_q == 1;
          end else if(valid0_q & !valid1_q) begin
            prev_pc_wdata_newst0 = prev_pc_wdata0_q;
            if(rvfi_valid[1])
                intr0_valid_d  = rvfi_order[2*64-1:64] - order0_q == 1;
            else
                intr0_valid_d  = rvfi_order[63:0] - order0_q == 1;
          end else if(valid1_q & valid0_q)
            if(order0_q > order1_q) begin
              prev_pc_wdata_newst0 = prev_pc_wdata0_q;
              if(rvfi_valid[1])
                  intr0_valid_d  = rvfi_order[2*64-1:64] - order0_q == 1;
              else
                  intr0_valid_d  = rvfi_order[63:0]      - order0_q == 1;
            end else begin
              prev_pc_wdata_newst0 = prev_pc_wdata1_q;
              if(rvfi_valid[1])
                  intr0_valid_d  = rvfi_order[2*64-1:64] - order1_q == 1;
              else
                  intr0_valid_d  = rvfi_order[63:0]      - order1_q == 1;
            end
          intr1_d = rvfi_valid[1] & (rvfi_pc_rdata[2*32-1:32] != prev_pc_wdata_newst0) & intr0_valid_d;
          intr0_d = rvfi_valid[0] & (rvfi_pc_rdata[31:0]      != prev_pc_wdata_newst0) & intr0_valid_d;
        end
      end

      else if(rvfi_valid[1] & rvfi_valid[0]) begin //both true

        //instr1 is the oldest
        if(rvfi_order[2*64-1:64] < rvfi_order[63:0]) begin

          //instr0 prev is instr1
          prev_pc_wdata_newst0 = rvfi_pc_wdata[2*32-1:32];
          intr0_valid_d        = rvfi_order[63:0] - rvfi_order[2*64-1:64] == 1;

          if(valid1_q & !valid0_q) begin
            prev_pc_wdata_newst1 = prev_pc_wdata1_q;
            intr1_valid_d        = rvfi_order[2*64-1:64] - order1_q == 1;
          end else if(valid0_q & !valid1_q) begin
            prev_pc_wdata_newst1 = prev_pc_wdata0_q;
            intr1_valid_d        = rvfi_order[2*64-1:64] - order0_q == 1;
          end else if(valid1_q & valid0_q) begin
            if(order0_q > order1_q) begin
              prev_pc_wdata_newst1 = prev_pc_wdata0_q;
              intr1_valid_d  = rvfi_order[2*64-1:64] - order0_q == 1;
            end else begin
              prev_pc_wdata_newst1 = prev_pc_wdata1_q;
              intr1_valid_d  = rvfi_order[2*64-1:64] - order1_q == 1;
            end
          end

          intr1_d = rvfi_valid[1] & (rvfi_pc_rdata[2*32-1:32] != prev_pc_wdata_newst1)& intr1_valid_d;
          intr0_d = rvfi_valid[0] & (rvfi_pc_rdata[31:0]      != prev_pc_wdata_newst0)& intr0_valid_d;

        end else begin
          //instr0 is the oldest
          $display("[ERROR] Instr1 is newer than Instr0 at time %t",$time);
          $stop;
        end

      end
    end

  for (genvar i = 0;i < RVFI_STAGES; i = i + 1) begin : g_rvfi_stages
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rvfi_stage_halt[i][0]      <= '0;
        rvfi_stage_trap[i][0]      <= '0;
        rvfi_stage_intr[i][0]      <= '0;
        rvfi_stage_order[i][0]     <= '0;
        rvfi_stage_insn[i][0]      <= '0;
        rvfi_stage_rs1_addr[i][0]  <= '0;
        rvfi_stage_rs2_addr[i][0]  <= '0;
        rvfi_stage_rs3_addr[i][0]  <= '0;
        rvfi_stage_pc_rdata[i][0]  <= '0;
        rvfi_stage_pc_wdata[i][0]  <= '0;
        rvfi_stage_mem_rmask[i][0] <= '0;
        rvfi_stage_mem_wmask[i][0] <= '0;
        rvfi_stage_valid[i][0]     <= '0;
        rvfi_stage_rs1_rdata[i][0] <= '0;
        rvfi_stage_rs2_rdata[i][0] <= '0;
        rvfi_stage_rs3_rdata[i][0] <= '0;
        rvfi_stage_rd1_wdata[i][0] <= '0;
        rvfi_stage_rd2_wdata[i][0] <= '0;
        rvfi_stage_rd1_addr[i][0]  <= '0;
        rvfi_stage_rd2_addr[i][0]  <= '0;
        rvfi_stage_mem_rdata[i][0] <= '0;
        rvfi_stage_mem_wdata[i][0] <= '0;
        rvfi_stage_mem_addr[i][0]  <= '0;

        rvfi_stage_halt[i][1]      <= '0;
        rvfi_stage_trap[i][1]      <= '0;
        rvfi_stage_intr[i][1]      <= '0;
        rvfi_stage_order[i][1]     <= '0;
        rvfi_stage_insn[i][1]      <= '0;
        rvfi_stage_rs1_addr[i][1]  <= '0;
        rvfi_stage_rs2_addr[i][1]  <= '0;
        rvfi_stage_rs3_addr[i][1]  <= '0;
        rvfi_stage_pc_rdata[i][1]  <= '0;
        rvfi_stage_pc_wdata[i][1]  <= '0;
        rvfi_stage_mem_rmask[i][1] <= '0;
        rvfi_stage_mem_wmask[i][1] <= '0;
        rvfi_stage_valid[i][1]     <= '0;
        rvfi_stage_rs1_rdata[i][1] <= '0;
        rvfi_stage_rs2_rdata[i][1] <= '0;
        rvfi_stage_rs3_rdata[i][1] <= '0;
        rvfi_stage_rd1_wdata[i][1] <= '0;
        rvfi_stage_rd2_wdata[i][1] <= '0;
        rvfi_stage_rd1_addr[i][1]  <= '0;
        rvfi_stage_rd2_addr[i][1]  <= '0;
        rvfi_stage_mem_rdata[i][1] <= '0;
        rvfi_stage_mem_wdata[i][1] <= '0;
        rvfi_stage_mem_addr[i][1]  <= '0;

        data_req_q[i]              <= '0;
        mret_q[i]                  <= '0;


      end else begin

        // Signals valid in ID stage
        // all the instructions treated the same
        if (i == 0) begin

          rvfi_stage_valid[i][0]    <= instr_id_done;

          if(instr_id_done) begin

            rvfi_stage_halt[i][0]      <= '0;
            rvfi_stage_trap[i][0]      <= illegal_insn_id_i;
            rvfi_stage_intr[i][0]      <= 1'b0;
            rvfi_stage_order[i][0]     <= rvfi_stage_order[i][0] + 64'b1;
            rvfi_stage_insn[i][0]      <= rvfi_insn_id;

            rvfi_stage_rs1_addr[i][0]  <= rvfi_rs1_addr_d;
            rvfi_stage_rs2_addr[i][0]  <= rvfi_rs2_addr_d;
            rvfi_stage_rs3_addr[i][0]  <= rvfi_rs3_addr_d;
            rvfi_stage_rs1_rdata[i][0] <= rvfi_rs1_data_d;
            rvfi_stage_rs2_rdata[i][0] <= rvfi_rs2_data_d;
            rvfi_stage_rs3_rdata[i][0] <= rvfi_rs3_data_d;
            rvfi_stage_rd1_addr[i][0]  <= rvfi_rd1_addr_d;
            rvfi_stage_rd2_addr[i][0]  <= rvfi_rd2_addr_d;

            rvfi_stage_pc_rdata[i][0]  <= pc_id_i;
            rvfi_stage_pc_wdata[i][0]  <= pc_set_i & is_jump_id_i ? jump_target_id_i : pc_if_i;

            rvfi_stage_mem_rmask[i][0] <= lsu_req_id_i & !lsu_we_id_i ? rvfi_mem_mask_int : 4'b0000;
            rvfi_stage_mem_wmask[i][0] <= lsu_req_id_i & lsu_we_id_i ? rvfi_mem_mask_int : 4'b0000;

            data_req_q[i]              <= lsu_req_id_i;
            mret_q[i]                  <= mret_insn_id_i;

          end
        end else if (i == 1) begin
          // Signals valid in EX stage

          //instructions retiring in the EX stage
          if(instr_ex_done & !data_req_q[i-1] & !(rvfi_stage_trap[i-1][0] || mret_q[i-1])) begin

            rvfi_stage_valid[i][0]     <= ex_stage_ready_q;

            rvfi_stage_halt[i][0]      <= rvfi_stage_halt[i-1][0];
            rvfi_stage_trap[i][0]      <= rvfi_stage_trap[i-1][0];
            rvfi_stage_intr[i][0]      <= rvfi_stage_intr[i-1][0];
            rvfi_stage_order[i][0]     <= rvfi_stage_order[i-1][0];
            rvfi_stage_insn[i][0]      <= rvfi_stage_insn[i-1][0];

            rvfi_stage_rs1_addr[i][0]  <= rvfi_stage_rs1_addr[i-1][0];
            rvfi_stage_rs2_addr[i][0]  <= rvfi_stage_rs2_addr[i-1][0];
            rvfi_stage_rs3_addr[i][0]  <= rvfi_stage_rs3_addr[i-1][0];
            rvfi_stage_rs1_rdata[i][0] <= rvfi_stage_rs1_rdata[i-1][0];
            rvfi_stage_rs2_rdata[i][0] <= rvfi_stage_rs2_rdata[i-1][0];
            rvfi_stage_rs3_rdata[i][0] <= rvfi_stage_rs3_rdata[i-1][0];
            rvfi_stage_rd1_addr[i][0]  <= rvfi_stage_rd1_addr[i-1][0];
            rvfi_stage_rd2_addr[i][0]  <= rvfi_stage_rd2_addr[i-1][0];
            // If writing to x0 zero write data as required by RVFI specification
            rvfi_stage_rd1_wdata[i][0] <= rvfi_stage_rd1_addr[i-1][0] == '0 ? '0 : rvfi_rd1_wdata_d;

            rvfi_stage_pc_rdata[i][0]  <= rvfi_stage_pc_rdata[i-1][0];
            rvfi_stage_pc_wdata[i][0]  <= pc_set_i & is_branch_ex_i ? branch_target_ex_i : rvfi_stage_pc_wdata[i-1][0];

            rvfi_stage_mem_rmask[i][0] <= rvfi_stage_mem_rmask[i-1][0];
            rvfi_stage_mem_wmask[i][0] <= rvfi_stage_mem_wmask[i-1][0];
            rvfi_stage_mem_addr[i][0]  <= rvfi_mem_addr_d;
            rvfi_stage_mem_wdata[i][0] <= rvfi_mem_wdata_d;

            if(data_req_q[i]) begin
              if(instr_wb_done & rvfi_stage_valid[i][1] & !data_misagligned_q)
                data_req_q[i] <= 1'b0;
            end
            mret_q[i]                  <= mret_q[i-1];

          end else rvfi_stage_valid[i][0] <= 1'b0;

          //instructions retiring in the WB stage
          if(instr_ex_done & data_req_q[i-1]) begin
            //true during first data req if GNT
            if(!lsu_misagligned_ex_i) begin
              rvfi_stage_valid[i][1]     <= ex_stage_ready_q;

              rvfi_stage_halt[i][1]      <= rvfi_stage_halt[i-1][0];
              rvfi_stage_trap[i][1]      <= rvfi_stage_trap[i-1][0];
              rvfi_stage_intr[i][1]      <= rvfi_stage_intr[i-1][0];
              rvfi_stage_order[i][1]     <= rvfi_stage_order[i-1][0];
              rvfi_stage_insn[i][1]      <= rvfi_stage_insn[i-1][0];

              rvfi_stage_rs1_addr[i][1]  <= rvfi_stage_rs1_addr[i-1][0];
              rvfi_stage_rs2_addr[i][1]  <= rvfi_stage_rs2_addr[i-1][0];
              rvfi_stage_rs3_addr[i][1]  <= rvfi_stage_rs3_addr[i-1][0];
              rvfi_stage_rs1_rdata[i][1] <= rvfi_stage_rs1_rdata[i-1][0];
              rvfi_stage_rs2_rdata[i][1] <= rvfi_stage_rs2_rdata[i-1][0];
              rvfi_stage_rs3_rdata[i][1] <= rvfi_stage_rs3_rdata[i-1][0];
              rvfi_stage_rd1_addr[i][1]  <= rvfi_stage_rd1_addr[i-1][0];
              rvfi_stage_rd2_addr[i][1]  <= rvfi_stage_rd2_addr[i-1][0];
              // If writing to x0 zero write data as required by RVFI specification
              rvfi_stage_rd1_wdata[i][1] <= rvfi_stage_rd1_addr[i-1][0] == '0 ? '0 : rvfi_rd1_wdata_d;

              rvfi_stage_pc_rdata[i][1]  <= rvfi_stage_pc_rdata[i-1][0];
              rvfi_stage_pc_wdata[i][1]  <= pc_set_i & is_branch_ex_i ? branch_target_ex_i : rvfi_stage_pc_wdata[i-1][0];

              rvfi_stage_mem_rmask[i][1] <= rvfi_stage_mem_rmask[i-1][0];
              rvfi_stage_mem_wmask[i][1] <= rvfi_stage_mem_wmask[i-1][0];
              rvfi_stage_mem_addr[i][1]  <= rvfi_mem_addr_d;
              rvfi_stage_mem_wdata[i][1] <= rvfi_mem_wdata_d;
              data_req_q[i]              <= data_req_q[i-1];
              mret_q[i]                  <= mret_q[i-1];
            end
          end

          //instructions retiring in the WB stage
          if(instr_ex_valid_i & (rvfi_stage_trap[i-1][0] || mret_q[i-1])) begin
              rvfi_stage_valid[i][1]     <= ex_stage_valid_q;

              rvfi_stage_halt[i][1]      <= rvfi_stage_halt[i-1][0];
              rvfi_stage_trap[i][1]      <= rvfi_stage_trap[i-1][0];
              rvfi_stage_intr[i][1]      <= rvfi_stage_intr[i-1][0];
              rvfi_stage_order[i][1]     <= rvfi_stage_order[i-1][0];
              rvfi_stage_insn[i][1]      <= rvfi_stage_insn[i-1][0];

              rvfi_stage_rs1_addr[i][1]  <= rvfi_stage_rs1_addr[i-1][0];
              rvfi_stage_rs2_addr[i][1]  <= rvfi_stage_rs2_addr[i-1][0];
              rvfi_stage_rs3_addr[i][1]  <= rvfi_stage_rs3_addr[i-1][0];
              rvfi_stage_rs1_rdata[i][1] <= rvfi_stage_rs1_rdata[i-1][0];
              rvfi_stage_rs2_rdata[i][1] <= rvfi_stage_rs2_rdata[i-1][0];
              rvfi_stage_rs3_rdata[i][1] <= rvfi_stage_rs3_rdata[i-1][0];
              rvfi_stage_rd1_addr[i][1]  <= rvfi_stage_rd1_addr[i-1][0];
              rvfi_stage_rd2_addr[i][1]  <= rvfi_stage_rd2_addr[i-1][0];
              // If writing to x0 zero write data as required by RVFI specification
              rvfi_stage_rd1_wdata[i][1] <= rvfi_stage_rd1_addr[i-1][0] == '0 ? '0 : rvfi_rd1_wdata_d;

              rvfi_stage_pc_rdata[i][1]  <= rvfi_stage_pc_rdata[i-1][0];
              rvfi_stage_pc_wdata[i][1]  <= pc_set_i & is_branch_ex_i ? branch_target_ex_i : rvfi_stage_pc_wdata[i-1][0];

              rvfi_stage_mem_rmask[i][1] <= rvfi_stage_mem_rmask[i-1][0];
              rvfi_stage_mem_wmask[i][1] <= rvfi_stage_mem_wmask[i-1][0];
              rvfi_stage_mem_addr[i][1]  <= rvfi_mem_addr_d;
              rvfi_stage_mem_wdata[i][1] <= rvfi_mem_wdata_d;
              data_req_q[i]              <= 1'b0;
              mret_q[i]                  <= mret_q[i-1];
          end

        end else if (i == 2) begin
          // Signals valid in WB stage

          case(1'b1)

            instr_wb_done & data_req_q[i-1]: begin

              rvfi_stage_valid[i][1]     <= rvfi_stage_valid[i-1][1] & !data_misagligned_q;
              rvfi_stage_halt[i][1]      <= rvfi_stage_halt[i-1][1];
              rvfi_stage_trap[i][1]      <= rvfi_stage_trap[i-1][1];
              rvfi_stage_intr[i][1]      <= rvfi_stage_intr[i-1][1];
              rvfi_stage_order[i][1]     <= rvfi_stage_order[i-1][1];
              rvfi_stage_insn[i][1]      <= rvfi_stage_insn[i-1][1];

              rvfi_stage_rs1_addr[i][1]  <= rvfi_stage_rs1_addr[i-1][1];
              rvfi_stage_rs2_addr[i][1]  <= rvfi_stage_rs2_addr[i-1][1];
              rvfi_stage_rs3_addr[i][1]  <= rvfi_stage_rs3_addr[i-1][1];
              rvfi_stage_rs1_rdata[i][1] <= rvfi_stage_rs1_rdata[i-1][1];
              rvfi_stage_rs2_rdata[i][1] <= rvfi_stage_rs2_rdata[i-1][1];
              rvfi_stage_rs3_rdata[i][1] <= rvfi_stage_rs3_rdata[i-1][1];
              rvfi_stage_rd1_addr[i][1]  <= rvfi_stage_rd1_addr[i-1][1];
              rvfi_stage_rd2_addr[i][1]  <= rvfi_stage_rd2_addr[i-1][1];
              rvfi_stage_rd1_wdata[i][1] <= rvfi_stage_rd1_wdata[i-1][1];
              // If writing to x0 zero write data as required by RVFI specification
              rvfi_stage_rd2_wdata[i][1] <= rvfi_stage_rd2_wdata[i-1][1];

              rvfi_stage_pc_rdata[i][1]  <= rvfi_stage_pc_rdata[i-1][1];
              rvfi_stage_pc_wdata[i][1]  <= rvfi_stage_pc_wdata[i-1][1];

              rvfi_stage_mem_rmask[i][1] <= rvfi_stage_mem_rmask[i-1][1];
              rvfi_stage_mem_wmask[i][1] <= rvfi_stage_mem_wmask[i-1][1];
              rvfi_stage_mem_addr[i][1]  <= rvfi_stage_mem_addr[i-1][1];
              rvfi_stage_mem_wdata[i][1] <= rvfi_stage_mem_wdata[i-1][1];
              rvfi_stage_mem_rdata[i][1] <= rvfi_rd2_wdata_d;


            end //instr_wb_done
            rvfi_stage_trap[i-1][1]: begin

              rvfi_stage_valid[i][1]     <= rvfi_stage_valid[i-1][1];
              rvfi_stage_halt[i][1]      <= rvfi_stage_halt[i-1][1];
              rvfi_stage_trap[i][1]      <= rvfi_stage_trap[i-1][1];
              rvfi_stage_intr[i][1]      <= rvfi_stage_intr[i-1][1];
              rvfi_stage_order[i][1]     <= rvfi_stage_order[i-1][1];
              rvfi_stage_insn[i][1]      <= rvfi_stage_insn[i-1][1];

              rvfi_stage_rs1_addr[i][1]  <= rvfi_stage_rs1_addr[i-1][1];
              rvfi_stage_rs2_addr[i][1]  <= rvfi_stage_rs2_addr[i-1][1];
              rvfi_stage_rs3_addr[i][1]  <= rvfi_stage_rs3_addr[i-1][1];
              rvfi_stage_rs1_rdata[i][1] <= rvfi_stage_rs1_rdata[i-1][1];
              rvfi_stage_rs2_rdata[i][1] <= rvfi_stage_rs2_rdata[i-1][1];
              rvfi_stage_rs3_rdata[i][1] <= rvfi_stage_rs3_rdata[i-1][1];
              rvfi_stage_rd1_addr[i][1]  <= rvfi_stage_rd1_addr[i-1][1];
              rvfi_stage_rd2_addr[i][1]  <= rvfi_stage_rd2_addr[i-1][1];
              rvfi_stage_rd1_wdata[i][1] <= rvfi_stage_rd1_wdata[i-1][1];
              // If writing to x0 zero write data as required by RVFI specification
              rvfi_stage_rd2_wdata[i][1] <= rvfi_stage_rd2_wdata[i-1][1];

              rvfi_stage_pc_rdata[i][1]  <= rvfi_stage_pc_rdata[i-1][1];
              rvfi_stage_pc_wdata[i][1]  <= rvfi_stage_pc_wdata[i-1][1];

              rvfi_stage_mem_rmask[i][1] <= rvfi_stage_mem_rmask[i-1][1];
              rvfi_stage_mem_wmask[i][1] <= rvfi_stage_mem_wmask[i-1][1];
              rvfi_stage_mem_addr[i][1]  <= rvfi_stage_mem_addr[i-1][1];
              rvfi_stage_mem_wdata[i][1] <= rvfi_stage_mem_wdata[i-1][1];
              rvfi_stage_mem_rdata[i][1] <= rvfi_stage_mem_rdata[i-1][1];
            end //instr_wb_done
            (mret_q[i-1] & rvfi_stage_valid[i-1][1] )|| mret_q[i]: begin
              //the MRET retires in one extra cycle, thus
              rvfi_stage_valid[i][1]     <= mret_q[i];
              rvfi_stage_halt[i][1]      <= rvfi_stage_halt[i-1][1];
              rvfi_stage_trap[i][1]      <= rvfi_stage_trap[i-1][1];
              rvfi_stage_intr[i][1]      <= rvfi_stage_intr[i-1][1];
              rvfi_stage_order[i][1]     <= rvfi_stage_order[i-1][1];
              rvfi_stage_insn[i][1]      <= rvfi_stage_insn[i-1][1];

              rvfi_stage_rs1_addr[i][1]  <= rvfi_stage_rs1_addr[i-1][1];
              rvfi_stage_rs2_addr[i][1]  <= rvfi_stage_rs2_addr[i-1][1];
              rvfi_stage_rs3_addr[i][1]  <= rvfi_stage_rs3_addr[i-1][1];
              rvfi_stage_rs1_rdata[i][1] <= rvfi_stage_rs1_rdata[i-1][1];
              rvfi_stage_rs2_rdata[i][1] <= rvfi_stage_rs2_rdata[i-1][1];
              rvfi_stage_rs3_rdata[i][1] <= rvfi_stage_rs3_rdata[i-1][1];
              rvfi_stage_rd1_addr[i][1]  <= rvfi_stage_rd1_addr[i-1][1];
              rvfi_stage_rd2_addr[i][1]  <= rvfi_stage_rd2_addr[i-1][1];
              rvfi_stage_rd1_wdata[i][1] <= rvfi_stage_rd1_wdata[i-1][1];
              // If writing to x0 zero write data as required by RVFI specification
              rvfi_stage_rd2_wdata[i][1] <= rvfi_stage_rd2_wdata[i-1][1];

              rvfi_stage_pc_rdata[i][1]  <= rvfi_stage_pc_rdata[i-1][1];
              rvfi_stage_pc_wdata[i][1]  <= is_mret_wb_i ? mepc_target_wb_i : exception_target_wb_i;

              rvfi_stage_mem_rmask[i][1] <= rvfi_stage_mem_rmask[i-1][1];
              rvfi_stage_mem_wmask[i][1] <= rvfi_stage_mem_wmask[i-1][1];
              rvfi_stage_mem_addr[i][1]  <= rvfi_stage_mem_addr[i-1][1];
              rvfi_stage_mem_wdata[i][1] <= rvfi_stage_mem_wdata[i-1][1];
              rvfi_stage_mem_rdata[i][1] <= rvfi_stage_mem_rdata[i-1][1];
              mret_q[i]                  <= !mret_q[i];
            end //instr_wb_done
            default:
              rvfi_stage_valid[i][1]     <= 1'b0;
            endcase
        end //i == 2


      end
    end
  end

  // Byte enable based on data type
  always_comb begin
    unique case (lsu_type_id_i)
      2'b00:   rvfi_mem_mask_int = 4'b1111;
      2'b01:   rvfi_mem_mask_int = 4'b0011;
      2'b10:   rvfi_mem_mask_int = 4'b0001;
      default: rvfi_mem_mask_int = 4'b0000;
    endcase
  end

  // Memory adddress
  assign rvfi_mem_addr_d = lsu_addr_ex_i;

  // Memory write data
  assign rvfi_mem_wdata_d = lsu_wdata_ex_i;


  always_comb begin
    if (instr_is_compressed_id_i) begin
      rvfi_insn_id = {16'b0, instr_rdata_c_id_i};
    end else begin
      rvfi_insn_id = instr_rdata_id_i;
    end
  end

  // Source registers
  always_comb begin
    rvfi_rs1_data_d = rdata_a_id_i;
    rvfi_rs1_addr_d = raddr_a_id_i;
    rvfi_rs2_data_d = rdata_b_id_i;
    rvfi_rs2_addr_d = raddr_b_id_i;
    rvfi_rs3_data_d = rdata_c_id_i;
    rvfi_rs3_addr_d = raddr_c_id_i;
  end

  // Destination registers
  always_comb begin
    if(rd1_we_id_i) begin
      // Capture address/data of write to register file
      rvfi_rd1_addr_d  = rd1_addr_id_i;
    end else begin
      // If no RF write then zero RF write address as required by RVFI specification
      rvfi_rd1_addr_d  = '0;
    end
  end
  //result from EX stage
  assign rvfi_rd1_wdata_d = rd1_wdata_ex_i;

  always_comb begin
    if(rd2_we_id_i) begin
      // Capture address/data of write to register file
      rvfi_rd2_addr_d  = rd2_addr_id_i;
    end else begin
      // If no RF write then zero RF write address/data as required by RVFI specification
      rvfi_rd2_addr_d  = '0;
    end
  end

  //result from WB stage/read value from Dmem
  assign rvfi_rd2_wdata_d = rd2_wdata_wb_i === 'x ? '0 : rd2_wdata_wb_i;


endmodule