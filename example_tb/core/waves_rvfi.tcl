# Copyright 2020 ETH Zurich
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set rvcores_rvfi [find instances -recursive -bydu cv32e40p_rvfi -nodu]



if {$rvcores_rvfi ne ""} {

  add wave -group "RVFI"                       $rvcores_rvfi/*

  add wave -group "RVFI" -group "Stage"        $rvcores_rvfi/rvfi_stage

}

configure wave -namecolwidth  250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns
