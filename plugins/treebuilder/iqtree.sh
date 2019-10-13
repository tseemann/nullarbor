#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

fconst=$(iqtree_constant_sites "$ref")
# one model, with bootstraps
iqtree -s "$aln" $fconst -redo -ntmax "$cpus" -nt AUTO -st DNA -m GTR+G4 -bb 1000 $opts
mv "$aln.treefile" "$tree"
