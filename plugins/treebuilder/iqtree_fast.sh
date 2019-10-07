#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

fconst=$(iqtree_constant_sites "$ref")
# one model, -fast mode, no bootstrap
iqtree -s "$aln" $fconst -redo -ntmax "$cpus" -nt AUTO -st DNA -fast -m GTR+G4 $opts
mv "$aln.treefile" "$tree"
