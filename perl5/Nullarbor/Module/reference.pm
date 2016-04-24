package Nullarbor::Module::reference;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................

my $MAX_CONTIGS = 10;
my $VERT_DOTS = '&#8942;';

#...........................................................................................

sub name {
  return "Reference genome";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
  
  my $fin = Bio::SeqIO->new(-file=>"$indir/ref.fa", -format=>'fasta');
  my $refsize = 0;
  my $ncontig = 0;
  my @ref;
  push @ref, [ qw(Sequence Length Description) ];
  while (my $seq = $fin->next_seq) {
    my $id = $seq->id;
#    $id =~ s/\|/~/g;
    push @ref, [ $id, $seq->length, ($seq->desc || 'no description') ] if $ncontig < $MAX_CONTIGS;
    $refsize += $seq->length;
    $ncontig++;
  }
  push @ref, [ $VERT_DOTS, $VERT_DOTS, "(skipped ".($ncontig-$MAX_CONTIGS)." sequences)" ] if $ncontig >= $MAX_CONTIGS;
  push @ref, [ 'TOTAL', $refsize, "Total reference size in bp" ];

  return $self->matrix_to_html(\@ref);
}

#...........................................................................................

1;

