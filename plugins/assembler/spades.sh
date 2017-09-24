#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

msg "This is $0"

echo spades.py -1 "$read1" -2 "$read2" -t "$cpus" --tmp-dir "$tmpdir/spades.$$" -o "$outdir" $opts
