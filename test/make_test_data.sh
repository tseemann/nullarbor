#!/bin/bash

SRC=genomes
LEN=150
TAB=input.tab

rm -f "$TAB"

for FASTA in $SRC/genome*.fa ; do
	N=$(basename $FASTA .fa)
	R1="${N}_R1.fq"
	R2="${N}_R2.fq"
	wgsim -N 10000 -1 $LEN -2 $LEN "$FASTA" "$R1" "$R2" > /dev/null
	sed 's/22/HH/g' < $R1 | gzip -c -f > $R1.gz
	sed 's/22/HH/g' < $R2 | gzip -c -f > $R2.gz
	rm -f $R1 $R2
	echo -e "$N\t$R1.gz\t$R2.gz" >> $TAB
done

cat $TAB

