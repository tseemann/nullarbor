#!/bin/bash

DIR="data"
TAB="$DIR/data.tab"
REF="$DIR/ref.fa"

rm -f $TAB

for F in $DIR/*.fa ; do
	N=$(basename $F .fa)
	#fq-simulate_illumina_reads.pl --ref $F --prefix $DIR/$N --indels --ambigs
	wgsim $F data/${N}_R1.fastq data/${N}_R2.fastq > /dev/null
	echo -e "$N\t$DIR/${N}_R1.fastq\t$DIR/${N}_R2.fastq" >> $TAB
	cp -f $F $REF 
done
