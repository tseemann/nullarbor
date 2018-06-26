#!/bin/sh

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

# 
iqtree -s "$aln" -redo -ntmax "$cpus" -st DNA $opts
mv "$aln.treefile" "$tree"
