#!/bin/sh

# INPUT  $1 = alignment file
# OUTPUT $2 = newick file

#OMP_NUM_THREADS=${CPUS:-1}
FastTree -nt -gtr "$1" > "$2"
