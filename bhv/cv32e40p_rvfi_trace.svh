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

// Includes to print info about the RVFI output
// Contributor: Davide Schiavone <davide@openhwgroup.org>

  typedef struct packed {
    logic        rvfi_stage_valid     ;
    logic [63:0] rvfi_stage_order     ;
    logic [31:0] rvfi_stage_insn      ;
    logic        rvfi_stage_trap      ;
    logic        rvfi_stage_halt      ;
    logic        rvfi_stage_intr      ;
    logic [ 4:0] rvfi_stage_rs1_addr  ;
    logic [ 4:0] rvfi_stage_rs2_addr  ;
    logic [ 4:0] rvfi_stage_rs3_addr  ;
    logic [31:0] rvfi_stage_rs1_rdata ;
    logic [31:0] rvfi_stage_rs2_rdata ;
    logic [31:0] rvfi_stage_rs3_rdata ;
    logic [ 4:0] rvfi_stage_rd1_addr  ;
    logic [ 4:0] rvfi_stage_rd2_addr  ;
    logic [31:0] rvfi_stage_rd1_wdata ;
    logic [31:0] rvfi_stage_rd2_wdata ;
    logic [31:0] rvfi_stage_pc_rdata  ;
    logic [31:0] rvfi_stage_pc_wdata  ;
    logic [31:0] rvfi_stage_mem_addr  ;
    logic [ 3:0] rvfi_stage_mem_rmask ;
    logic [ 3:0] rvfi_stage_mem_wmask ;
    logic [31:0] rvfi_stage_mem_rdata ;
    logic [31:0] rvfi_stage_mem_wdata ;
  } rvfi_instr_t;




  integer      f;
  string       fn;
  string insn_str;

  initial begin

    wait(rst_ni == 1'b1);
    $sformat(fn, "trace_rvfi_%h.log", hart_id_i);
    f = $fopen(fn, "w");
    $fwrite(f, "order\tinsn\trs1_addr\trs1_rdata\trs2_addr\trs2_rdata\trd1_addr\trd1_wdata\t\tpc_rdat\tmem_addr\tmem_rdata\tmem_wdata\tTRAP\tINTR\n");

    while(1) begin

      @(posedge clk_i)

      if(rvfi_valid[0] | rvfi_valid[1]) begin

        if( rvfi_valid[1] ) begin
          insn_str = $sformatf(
                          "%h\t%h\t%h\t%h\t%h\t%h\t%h\t%h\tPC=%h\t%h\t%h\t%h\t%h\t%h",
                          rvfi_order[64+15:64],
                          rvfi_insn[2*32-1:32],
                          rvfi_rs1_addr[9:5],
                          rvfi_rs1_rdata[2*32-1:32],
                          rvfi_rs2_addr[9:5],
                          rvfi_rs2_rdata[2*32-1:32],
                          rvfi_rd1_addr[9:5],
                          rvfi_rd1_wdata[2*32-1:32],
                          rvfi_pc_rdata[2*32-1:32],
                          rvfi_mem_addr[2*32-1:32],
                          rvfi_mem_rdata[2*32-1:32],
                          rvfi_mem_wdata[2*32-1:32],
                          rvfi_trap[1],
                          rvfi_intr[1] );
          $fwrite(f, "%s\n", insn_str);
        end

        if( rvfi_valid[0] ) begin
          insn_str = $sformatf(
                          "%h\t%h\t%h\t%h\t%h\t%h\t%h\t%h\tPC=%h\t%h\t%h\t%h\t%h\t%h",
                          rvfi_order[15:0],
                          rvfi_insn[31:0],
                          rvfi_rs1_addr[4:0],
                          rvfi_rs1_rdata[31:0],
                          rvfi_rs2_addr[4:0],
                          rvfi_rs2_rdata[31:0],
                          rvfi_rd1_addr[4:0],
                          rvfi_rd1_wdata[31:0],
                          rvfi_pc_rdata[31:0],
                          rvfi_mem_addr[31:0],
                          rvfi_mem_rdata[31:0],
                          rvfi_mem_wdata[31:0],
                          rvfi_trap[0],
                          rvfi_intr[0] );
          $fwrite(f, "%s\n", insn_str);
        end


      end
    end

  end
