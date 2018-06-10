#!/bin/sh

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

OMP_NUM_THREADS="$cpus"
FastTree -gtr "$opts" -nt "$aln" | nw_order -c -n - > "$tree"
