#!/bin/sh

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

#iqtree -s "$aln" -st DNA -m GTR -nt AUTO -ntmax "$cpus" -redo "$opts"
#iqtree -redo -s "$aln" -ntmax "$cpus" -redo "$opts"
iqtree -s "$aln" -redo -ntmax "$cpus" -st DNA
mv "$aln.treefile" "$tree"
