#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

WORKDIR=$(mktemp -d)

# gffout="$(@)" gbkout="$(@D)/contigs.gbk" "contigs=$(<)" locustag="$(@D)" gcode="$(GCODE)" minlen="$(MIN_

# We use --notrna because sometimes good CDS are masked by bad Aragorn calls

PREFIX=prokka

prokka --force --outdir "$WORKDIR" --prefix "$PREFIX" --locustag "$locustag" \
	--gcode "$gcode" --mincontiglen "$minlen" --strain "$locustag" \
	--notrna --fast \
	"$contigs"

cp -v -f "$WORKDIR/$PREFIX.gff" "$gffout"
cp -v -f "$WORKDIR/$PREFIX.gbk" "$gbkout"

rm -frv "$WORKDIR"
