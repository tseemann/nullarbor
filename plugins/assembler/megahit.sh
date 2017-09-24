#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

msg "This is $0"

echo shovill --outdir "$outdir" --R1 "$read1" --R2 "$read2" --cpus "$cpus" --tmpdir "$tmpdir/spades.$$" -o "$outdir" $opts
