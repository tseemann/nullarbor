#!/bin/bash

REF=genomes/ref.fa
OUTDIR=nullarbor

rm -fr ./$OUTDIR

nullarbor.pl --ref $REF --input input.tab --outdir $OUTDIR --name Nullarbor-Test --force \
	  && nice make -j 4 -C $OUTDIR

