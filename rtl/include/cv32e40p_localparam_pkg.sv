// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Pasquale Davide Schiavone - davide@openhwgroup.org         //
//                                                                            //
//                                                                            //
// Design Name:    Localparameter of CV32E40P                                 //
// Project Name:   CV32E40P                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    localparameter used by the processor core.                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

package cv32e40p_localparam_pkg;

  // Unused parameters and signals (left in code for future design extensions)
  localparam PULP_SECURE         =  0;
  localparam N_PMP_ENTRIES       = 16;
  localparam USE_PMP             =  0;          // if PULP_SECURE is 1, you can still not use the PMP
  localparam A_EXTENSION         =  0;
  localparam DEBUG_TRIGGER_EN    =  1;

  // PULP bus interface behavior
  // If enabled will allow non-stable address phase signals during waited instructions requests and
  // will re-introduce combinatorial paths from instr_rvalid_i to instr_req_o and from from data_rvalid_i
  // to data_req_o
  localparam PULP_OBI            = 0;

  // Unused signals related to above unused parameters
  // Left in code (with their original _i, _o postfixes) for future design extensions;
  // these used to be former inputs/outputs of RI5CY

  localparam N_HWLP      = 2;
  localparam N_HWLP_BITS = $clog2(N_HWLP);


endpackage
