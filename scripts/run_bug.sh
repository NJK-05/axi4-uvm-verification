#!/bin/bash
# usage: scripts/run_bug.sh <bug_id> <test_name>   (run from the project root)
BUG=${1:-0}
TEST=${2:-axi4_rand_test}
OUT=build/bug${BUG}_${TEST}
mkdir -p "$OUT"
cd "$OUT" || exit 1
R=../..
xvlog -sv -L uvm -d BUG_ID=$BUG -i $R/uvm -i $R/uvm/agent -i $R/uvm/env -i $R/uvm/seq -i $R/uvm/test \
    $R/rtl/axi4_if.sv $R/rtl/axi4_slave_mem.sv $R/sva/axi4_protocol_checker.sv $R/uvm/axi4_pkg.sv $R/tb/tb_axi4_uvm_top.sv > compile.log 2>&1 || { echo "COMPILE FAILED ($OUT/compile.log):"; grep -E "ERROR|error" compile.log | head -8; exit 1; }
xelab -L uvm --timescale 1ns/1ps tb_axi4_uvm_top -s snap > elab.log 2>&1 || { echo "ELAB FAILED ($OUT/elab.log):"; grep -E "ERROR|error" elab.log | head -8; exit 1; }
xsim snap -testplusarg UVM_TESTNAME=$TEST -runall > run.log 2>&1
