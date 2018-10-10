#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

skesa --fastq "$read1,$read2" \
      --cores "$cpus" \
      --vector_percent 1.0 \
      $opts \
      --contigs_out "$outdir/contigs.fa"
