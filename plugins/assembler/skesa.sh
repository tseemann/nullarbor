#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

#WORKDIR=$(mktemp -d)

skesa --use_paired_ends --gz --fastq "$read1,$read2" \
	--cores "$cpus" --memory 16 \
	--contigs_out "$outdir/contigs.fa"

#cp -v -f "$WORKDIR/"contigs.{fa,gfa} "$outdir"
#cat "$WORKDIR/"*.log > "$outdir/contigs.log"
#rm -frv "$WORKDIR"

