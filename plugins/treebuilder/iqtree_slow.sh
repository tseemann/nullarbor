#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

# 
iqtree -s "$aln" -redo -ntmax "$cpus" -nt AUTO -st DNA -bb 1000 -alrt 1000 $opts
mv "$aln.treefile" "$tree"
