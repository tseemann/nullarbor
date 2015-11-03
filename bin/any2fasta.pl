#!/usr/bin/env perl
use strict;
use Bio::SeqIO;

@ARGV or die "Usage: $0 file.{gbk,fna,embl,...} > file.fna";

my $in = Bio::SeqIO->new(-file=>$ARGV[0]);
my $out = Bio::SeqIO->new(-fh=>\*STDOUT, -format=>'Fasta');

while (my $seq = $in->next_seq) {
  $out->write_seq($seq);
}

