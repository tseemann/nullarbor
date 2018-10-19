#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

# https://github.com/ncbi/SKESA/issues/11

skesa --fastq "$read1" --fastq "$read2" \
      --cores "$cpus" \
      --vector_percent 1.0 \
      --kmer 51 \
      --steps 1 \
      $opts \
      --contigs_out "$outdir/contigs.fa"
