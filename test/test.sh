#!/bin/bash

REF=genomes/ref.fa
OUTDIR=nullarbor

rm -fr ./$OUTDIR

../bin/nullarbor.pl --ref $REF --input input.tab --outdir $OUTDIR --name NullarborTest --force \
	  && nice make -j 4 -C $OUTDIR

