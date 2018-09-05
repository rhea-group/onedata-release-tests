#!/usr/bin/env bash
choice=${2:-"small"}
nper_node=${1:-"1"}

./perf.sh $nper_node $choice false false false
