#!/bin/sh

# INPUT  $1 = alignment file
# OUTPUT $2 = newick file

PREFIX=iqtree.tmp

iqtree -s "$1" -st DNA -m GTR -nt "${CPUS:-1}" -pre "$PREFIX"
mv "$PREFIX.treefile" "$2"
rm -f "$PREFIX".*
