#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

fconst=$(iqtree_constant_sites "$ref")
# full model test 
iqtree -s "$aln" $fconst -redo -ntmax "$cpus" -nt AUTO -st DNA -bb 1000 -alrt 1000 $opts
mv "$aln.treefile" "$tree"
