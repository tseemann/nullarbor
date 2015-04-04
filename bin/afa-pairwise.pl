#!/usr/bin/env perl
use warnings;
use strict;
use Bio::SeqIO;

my(@Options, $verbose, $sep);
setOptions();

my %seq;
my $afa = Bio::SeqIO->new(-fh=>\*ARGV, -format=>'fasta');
while (my $seq = $afa->next_seq) {
  $seq{ $seq->id } = $seq->seq;
}

my @id = sort keys %seq;

print join($sep, 'ID', @id),"\n";
for my $i (0 .. $#id) {
  my @row = ($id[$i]);
  for my $j (0 .. $#id) {
#    my $d = $i==$j ? 0 : distance( $seq{ $id[$i] }, $seq{ $id[$j] } );
#    push @row, $d;
#     push @row, distance( $seq{ $id[$i] }, $seq{ $id[$j] } );
    my $d = distance( $seq{ $id[$i] }, $seq{ $id[$j] } );
    push @row, $d;
  }
  print join($sep, @row), "\n";
}

sub distance {
  my($s, $t) = @_;
  my $L = length($s);
  die "Strings not same length!" if $L != length($t);  
  my $diff = 0;
  for my $i (0 .. $L-1) {
    $diff++ if substr($s,$i,1) ne substr($t,$i,1);
  }
  return $diff;
}

#----------------------------------------------------------------------
# Option setting routines

sub setOptions {
  use Getopt::Long;

  @Options = (
    {OPT=>"help",    VAR=>\&usage,             DESC=>"This help"},
    {OPT=>"verbose!",  VAR=>\$verbose, DEFAULT=>0, DESC=>"Verbose output"},
    {OPT=>"sep=s",  VAR=>\$sep, DEFAULT=>"\t", DESC=>"Output separator char"},
  );

  (!@ARGV) && (usage());

  &GetOptions(map {$_->{OPT}, $_->{VAR}} @Options) || usage();

  # Now setup default values.
  foreach (@Options) {
    if (defined($_->{DEFAULT}) && !defined(${$_->{VAR}})) {
      ${$_->{VAR}} = $_->{DEFAULT};
    }
  }
}

sub usage {
  print "Usage: $0 [options] <snps.aln>\n";
  foreach (@Options) {
    printf "  --%-13s %s%s.\n",$_->{OPT},$_->{DESC},
           defined($_->{DEFAULT}) ? " (default '$_->{DEFAULT}')" : "";
  }
  exit(1);
}
 
#----------------------------------------------------------------------
