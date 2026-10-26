#!/bin/bash
# usage: scripts/run_regression.sh   (run from the project root, after sourcing the Vivado settings64.sh)
mkdir -p build
TESTS="axi4_directed_test axi4_rand_test axi4_cross_test"
BUGS="0 1 2 3 4 5 6 7 8 9 10"
printf "%-4s %-16s %-8s %-8s %-8s %-8s\n" bug test sb_mism mon_err sva_fail verdict
for b in $BUGS; do
  for t in $TESTS; do
    scripts/run_bug.sh $b $t
    L=build/bug${b}_${t}/run.log
    [ -f "$L" ] || { printf "%-4s %-16s %s\n" $b $t "NO LOG"; continue; }
    sb=$(grep -o "SB_SUMMARY.* \([0-9]*\) mismatches" $L | grep -o "[0-9]* mismatches" | grep -o "^[0-9]*")
    mon=$(grep -o "^\[AXI4_MONITOR\] *[0-9]*" $L | grep -o "[0-9]*$")
    sva=$(grep -o "\[SVA\] summary: [0-9]*" $L | grep -o "[0-9]*$")
    : ${sb:=?}; : ${mon:=0}; : ${sva:=?}
    if [ "$sb" = "0" ] && [ "$mon" = "0" ] && [ "$sva" = "0" ]; then v=CLEAN; else v=CAUGHT; fi
    printf "%-4s %-16s %-8s %-8s %-8s %-8s\n" $b $t "$sb" "$mon" "$sva" $v
  done
done | tee build/regression.txt
