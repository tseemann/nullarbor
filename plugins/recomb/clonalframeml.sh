#!/bin/bash

base="$( cd "$( dirname "$0" )" && pwd )"
. "$base/../common.inc"
. "$base/common.inc"

msg "This is $0"

echo ClonalFrameML "$tree" "$aligment" "$outdir/cfml"

