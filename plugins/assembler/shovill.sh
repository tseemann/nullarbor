#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

WORKDIR=$(mktemp -d)

shovill --force --outdir "$WORKDIR" --R1 "$read1" --R2 "$read2" --cpus "$cpus" --ram 16 $opts

cp -v -f "$WORKDIR/"contigs.{fa,gfa} "$outdir"
cat "$WORKDIR/"*.log > "$outdir/contigs.log"

rm -frv "$WORKDIR"
