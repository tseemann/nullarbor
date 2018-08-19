#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

gzipped=""
if [[ $read1 =~ gz$ ]]; then
    gzipped="--gz"
fi

skesa --use_paired_ends $gzipped --fastq "$read1,$read2" \
	--cores "$cpus" --memory 16 $opts \
	--contigs_out "$outdir/contigs.fa"
