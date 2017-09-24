#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

WORKDIR=$(mktemp -d)

# it does not have a --force option
OUTDIR="$WORKDIR/megahit"
megahit --min-count 3 --k-list 21,31,41,53,75,97,111,127 --out-dir "$OUTDIR" --memory 0.5 -1 "$read1" -2 "$read2" -t "$cpus" $opts

cp -v -f "$OUTDIR/final.contigs.fa" "$outdir/contigs.fa"
cp -v -f "$OUTDIR/log" "$outdir/contigs.log"

rm -frv "$WORKDIR"
