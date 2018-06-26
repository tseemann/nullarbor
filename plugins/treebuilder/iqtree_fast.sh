#!/bin/sh

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

iqtree -s "$aln" -redo -ntmax "$cpus" -st DNA -fast -m GTR+G4 $opts
mv "$aln.treefile" "$tree"
