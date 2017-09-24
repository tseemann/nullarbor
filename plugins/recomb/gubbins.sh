#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

msg "This is $0"

echo run_gubbins.py --prefix "$outdir/gubbins" --threads "$cpus" $opts
