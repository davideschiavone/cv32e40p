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

module cv32e40p_rvfi (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic [31:0] hart_id_i,

  input  logic        irq_ack_i,
  input  logic        illegal_insn_id_i,
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

  input  logic        instr_wb_ready_i,
  input  logic [31:0] rd2_wdata_wb_i,

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
  output logic        rvfi_valid,
  output logic [63:0] rvfi_order,
  output logic [31:0] rvfi_insn,
  output logic        rvfi_trap,
  output logic        rvfi_halt,
  output logic        rvfi_intr,
  output logic [ 1:0] rvfi_mode,
  output logic [ 1:0] rvfi_ixl,
  output logic [ 4:0] rvfi_rs1_addr,
  output logic [ 4:0] rvfi_rs2_addr,
  output logic [ 4:0] rvfi_rs3_addr,
  output logic [31:0] rvfi_rs1_rdata,
  output logic [31:0] rvfi_rs2_rdata,
  output logic [31:0] rvfi_rs3_rdata,
  output logic [ 4:0] rvfi_rd1_addr,
  output logic [31:0] rvfi_rd1_wdata,
  output logic [ 4:0] rvfi_rd2_addr,
  output logic [31:0] rvfi_rd2_wdata,
  output logic [31:0] rvfi_pc_rdata,
  output logic [31:0] rvfi_pc_wdata,
  output logic [31:0] rvfi_mem_addr,
  output logic [ 3:0] rvfi_mem_rmask,
  output logic [ 3:0] rvfi_mem_wmask,
  output logic [31:0] rvfi_mem_rdata,
  output logic [31:0] rvfi_mem_wdata

);

  logic        rvfi_instr_new_wb;
  logic        rvfi_intr_d;
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

  logic        rvfi_stage_valid     [RVFI_STAGES];
  logic [63:0] rvfi_stage_order     [RVFI_STAGES];
  logic [31:0] rvfi_stage_insn      [RVFI_STAGES];
  logic        rvfi_stage_trap      [RVFI_STAGES];
  logic        rvfi_stage_halt      [RVFI_STAGES];
  logic        rvfi_stage_intr      [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rs1_addr  [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rs2_addr  [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rs3_addr  [RVFI_STAGES];
  logic [31:0] rvfi_stage_rs1_rdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_rs2_rdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_rs3_rdata [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rd1_addr  [RVFI_STAGES];
  logic [ 4:0] rvfi_stage_rd2_addr  [RVFI_STAGES];
  logic [31:0] rvfi_stage_rd1_wdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_rd2_wdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_pc_rdata  [RVFI_STAGES];
  logic [31:0] rvfi_stage_pc_wdata  [RVFI_STAGES];
  logic [31:0] rvfi_stage_mem_addr  [RVFI_STAGES];
  logic [ 3:0] rvfi_stage_mem_rmask [RVFI_STAGES];
  logic [ 3:0] rvfi_stage_mem_wmask [RVFI_STAGES];
  logic [31:0] rvfi_stage_mem_rdata [RVFI_STAGES];
  logic [31:0] rvfi_stage_mem_wdata [RVFI_STAGES];

  logic        data_req_q   [RVFI_STAGES];
  logic        data_misagligned_q   [RVFI_STAGES];


  logic        instr_id_done;
  logic        instr_ex_done;
  logic        instr_wb_done;

  `include "cv32e40p_rvfi_trace.svh"

  assign rvfi_valid     = rvfi_stage_valid    [RVFI_STAGES-1];
  assign rvfi_order     = rvfi_stage_order    [RVFI_STAGES-1];
  assign rvfi_insn      = rvfi_stage_insn     [RVFI_STAGES-1];
  assign rvfi_trap      = rvfi_stage_trap     [RVFI_STAGES-1];
  assign rvfi_halt      = rvfi_stage_halt     [RVFI_STAGES-1];
  assign rvfi_intr      = rvfi_stage_intr     [RVFI_STAGES-1];
  assign rvfi_mode      = 2'b11;
  assign rvfi_ixl       = 2'b01;
  assign rvfi_rs1_addr  = rvfi_stage_rs1_addr [RVFI_STAGES-1];
  assign rvfi_rs2_addr  = rvfi_stage_rs2_addr [RVFI_STAGES-1];
  assign rvfi_rs3_addr  = rvfi_stage_rs3_addr [RVFI_STAGES-1];
  assign rvfi_rs1_rdata = rvfi_stage_rs1_rdata[RVFI_STAGES-1];
  assign rvfi_rs2_rdata = rvfi_stage_rs2_rdata[RVFI_STAGES-1];
  assign rvfi_rs3_rdata = rvfi_stage_rs3_rdata[RVFI_STAGES-1];
  assign rvfi_rd1_addr  = rvfi_stage_rd1_addr [RVFI_STAGES-1];
  assign rvfi_rd2_addr  = rvfi_stage_rd2_addr [RVFI_STAGES-1];
  assign rvfi_rd1_wdata = rvfi_stage_rd1_wdata [RVFI_STAGES-1];
  assign rvfi_rd2_wdata = rvfi_stage_rd2_wdata [RVFI_STAGES-1];
  assign rvfi_pc_rdata  = rvfi_stage_pc_rdata [RVFI_STAGES-1];
  assign rvfi_pc_wdata  = rvfi_stage_pc_wdata [RVFI_STAGES-1];
  assign rvfi_mem_addr  = rvfi_stage_mem_addr [RVFI_STAGES-1];
  assign rvfi_mem_rmask = rvfi_stage_mem_rmask[RVFI_STAGES-1];
  assign rvfi_mem_wmask = rvfi_stage_mem_wmask[RVFI_STAGES-1];
  assign rvfi_mem_rdata = rvfi_stage_mem_rdata[RVFI_STAGES-1];
  assign rvfi_mem_wdata = rvfi_stage_mem_wdata[RVFI_STAGES-1];


  // An instruction in the ID stage is valid (instr_id_valid_i)
  // when it's not stalled by the EX stage
  // due to stalls in the EX stage, data hazards, or if it is not halted by the controller
  // as due interrupts, debug requests, illegal instructions, ebreaks and ecalls
  assign instr_id_done  = instr_id_valid_i & instr_id_is_decoding_i;

  assign instr_ex_done  = instr_ex_ready_i;

  assign instr_wb_done  = data_req_q[1] ? instr_ex_valid_i : instr_wb_ready_i;


  for (genvar i = 0;i < RVFI_STAGES; i = i + 1) begin : g_rvfi_stages
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rvfi_stage_halt[i]      <= '0;
        rvfi_stage_trap[i]      <= '0;
        rvfi_stage_intr[i]      <= '0;
        rvfi_stage_order[i]     <= '0;
        rvfi_stage_insn[i]      <= '0;
        rvfi_stage_rs1_addr[i]  <= '0;
        rvfi_stage_rs2_addr[i]  <= '0;
        rvfi_stage_rs3_addr[i]  <= '0;
        rvfi_stage_pc_rdata[i]  <= '0;
        rvfi_stage_pc_wdata[i]  <= '0;
        rvfi_stage_mem_rmask[i] <= '0;
        rvfi_stage_mem_wmask[i] <= '0;
        rvfi_stage_valid[i]     <= '0;
        rvfi_stage_rs1_rdata[i] <= '0;
        rvfi_stage_rs2_rdata[i] <= '0;
        rvfi_stage_rs3_rdata[i] <= '0;
        rvfi_stage_rd1_wdata[i] <= '0;
        rvfi_stage_rd2_wdata[i] <= '0;
        rvfi_stage_rd1_addr[i]  <= '0;
        rvfi_stage_rd2_addr[i]  <= '0;
        rvfi_stage_mem_rdata[i] <= '0;
        rvfi_stage_mem_wdata[i] <= '0;
        rvfi_stage_mem_addr[i]  <= '0;
        data_req_q[i]           <= '0;
        data_misagligned_q[i]   <= '0;

      end else begin

        // Signals valid in ID stage
        if (i == 0) begin

          rvfi_stage_valid[i]     <= instr_id_done;

          if(instr_id_done) begin

            rvfi_stage_halt[i]      <= '0;
            rvfi_stage_trap[i]      <= illegal_insn_id_i;
            rvfi_stage_intr[i]      <= rvfi_intr_d;
            rvfi_stage_order[i]     <= rvfi_stage_order[i] + 64'b1;
            rvfi_stage_insn[i]      <= rvfi_insn_id;

            rvfi_stage_rs1_addr[i]  <= rvfi_rs1_addr_d;
            rvfi_stage_rs2_addr[i]  <= rvfi_rs2_addr_d;
            rvfi_stage_rs3_addr[i]  <= rvfi_rs3_addr_d;
            rvfi_stage_rs1_rdata[i] <= rvfi_rs1_data_d;
            rvfi_stage_rs2_rdata[i] <= rvfi_rs2_data_d;
            rvfi_stage_rs3_rdata[i] <= rvfi_rs3_data_d;
            rvfi_stage_rd1_addr[i]  <= rvfi_rd1_addr_d;
            rvfi_stage_rd2_addr[i]  <= rvfi_rd2_addr_d;

            rvfi_stage_pc_rdata[i]  <= pc_id_i;
            rvfi_stage_pc_wdata[i]  <= pc_set_i & is_jump_id_i ? jump_target_id_i : pc_if_i;

            rvfi_stage_mem_rmask[i] <= lsu_req_id_i & !lsu_we_id_i ? rvfi_mem_mask_int : 4'b0000;
            rvfi_stage_mem_wmask[i] <= lsu_req_id_i & lsu_we_id_i ? rvfi_mem_mask_int : 4'b0000;

          end
        end else if (i == 1) begin
          // Signals valid in EX stage

          rvfi_stage_valid[i]       <= rvfi_stage_valid[i-1] & instr_ex_done;

          if(instr_ex_done) begin

            rvfi_stage_halt[i]      <= rvfi_stage_halt[i-1];
            rvfi_stage_trap[i]      <= rvfi_stage_trap[i-1];
            rvfi_stage_intr[i]      <= rvfi_stage_intr[i-1];
            rvfi_stage_order[i]     <= rvfi_stage_order[i-1];
            rvfi_stage_insn[i]      <= rvfi_stage_insn[i-1];

            rvfi_stage_rs1_addr[i]  <= rvfi_stage_rs1_addr[i-1];
            rvfi_stage_rs2_addr[i]  <= rvfi_stage_rs2_addr[i-1];
            rvfi_stage_rs3_addr[i]  <= rvfi_stage_rs3_addr[i-1];
            rvfi_stage_rs1_rdata[i] <= rvfi_stage_rs1_rdata[i-1];
            rvfi_stage_rs2_rdata[i] <= rvfi_stage_rs2_rdata[i-1];
            rvfi_stage_rs3_rdata[i] <= rvfi_stage_rs3_rdata[i-1];
            rvfi_stage_rd1_addr[i]  <= rvfi_stage_rd1_addr[i-1];
            rvfi_stage_rd2_addr[i]  <= rvfi_stage_rd2_addr[i-1];
            // If writing to x0 zero write data as required by RVFI specification
            rvfi_stage_rd1_wdata[i] <= rvfi_stage_rd1_addr[i-1] == '0 ? '0 : rvfi_rd1_wdata_d;

            rvfi_stage_pc_rdata[i]  <= rvfi_stage_pc_rdata[i-1];
            rvfi_stage_pc_wdata[i]  <= pc_set_i & is_branch_ex_i ? branch_target_ex_i : rvfi_stage_pc_wdata[i-1];

            rvfi_stage_mem_rmask[i] <= rvfi_stage_mem_rmask[i-1];
            rvfi_stage_mem_wmask[i] <= rvfi_stage_mem_wmask[i-1];
            rvfi_stage_mem_addr[i]  <= rvfi_mem_addr_d;
            rvfi_stage_mem_wdata[i] <= rvfi_mem_wdata_d;

            data_misagligned_q[i]   <= lsu_misagligned_ex_i;
            data_req_q[i]           <= lsu_req_ex_i;

          end

        end else if (i == 2) begin
          // Signals valid in WB stage


          rvfi_stage_valid[i]       <= rvfi_stage_valid[i-1] & instr_wb_done;

          if(instr_wb_done) begin //ex_valid_o

            rvfi_stage_valid[i]     <= rvfi_stage_valid[i-1];
            rvfi_stage_halt[i]      <= rvfi_stage_halt[i-1];
            rvfi_stage_trap[i]      <= rvfi_stage_trap[i-1];
            rvfi_stage_intr[i]      <= rvfi_stage_intr[i-1];
            rvfi_stage_order[i]     <= rvfi_stage_order[i-1];
            rvfi_stage_insn[i]      <= rvfi_stage_insn[i-1];

            rvfi_stage_rs1_addr[i]  <= rvfi_stage_rs1_addr[i-1];
            rvfi_stage_rs2_addr[i]  <= rvfi_stage_rs2_addr[i-1];
            rvfi_stage_rs3_addr[i]  <= rvfi_stage_rs3_addr[i-1];
            rvfi_stage_rs1_rdata[i] <= rvfi_stage_rs1_rdata[i-1];
            rvfi_stage_rs2_rdata[i] <= rvfi_stage_rs2_rdata[i-1];
            rvfi_stage_rs3_rdata[i] <= rvfi_stage_rs3_rdata[i-1];
            rvfi_stage_rd1_addr[i]  <= rvfi_stage_rd1_addr[i-1];
            rvfi_stage_rd2_addr[i]  <= rvfi_stage_rd2_addr[i-1];
            rvfi_stage_rd1_wdata[i] <= rvfi_stage_rd1_wdata[i-1];
            // If writing to x0 zero write data as required by RVFI specification
            rvfi_stage_rd2_wdata[i] <= rvfi_stage_rd2_addr[i-1] == '0 ? '0 : rvfi_rd2_wdata_d;

            rvfi_stage_pc_rdata[i]  <= rvfi_stage_pc_rdata[i-1];
            rvfi_stage_pc_wdata[i]  <= rvfi_stage_pc_wdata[i-1];

            rvfi_stage_mem_rmask[i] <= rvfi_stage_mem_rmask[i-1];
            rvfi_stage_mem_wmask[i] <= rvfi_stage_mem_wmask[i-1];
            rvfi_stage_mem_addr[i]  <= data_misagligned_q[i-1] ? rvfi_stage_mem_addr[i] : rvfi_stage_mem_addr[i-1];
            rvfi_stage_mem_wdata[i] <= rvfi_stage_mem_wdata[i-1];
            rvfi_stage_mem_rdata[i] <= rvfi_rd2_wdata_d;

            //rvfi_stage_valid[i]     <= data_misagligned_q[i-1] ? 1'b0 : 1'b1;

          end //instr_wb_done
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
  assign rvfi_rd2_wdata_d = rd2_wdata_wb_i;


endmodule