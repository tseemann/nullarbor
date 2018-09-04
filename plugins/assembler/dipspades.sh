#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

WORKDIR=$(mktemp -d)

# THIS IS FOR DIPLOID FUNGAL GENOMES

echo "# $0"
echo "# $WORKDIR"

# it does not have a --force option
OUTDIR="$WORKDIR/dipspades"
dipspades.py -o "$OUTDIR" -1 "$read1" -2 "$read2" -t "$cpus" $opts

# dipspades creates 2 subfolders - we just take the 'consensus contigs'
cp -v -f "$OUTDIR/dipspades/consensus_contigs.fasta" "$outdir/contigs.fa"
cp -v -f "$OUTDIR/dipspades/dipspades.log" "$outdir/contigs.log"

# cleanup
rm -frv "$WORKDIR"
