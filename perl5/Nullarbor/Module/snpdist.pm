package Nullarbor::Module::snpdist;
use Moo;
extends 'Nullarbor::Module';

#...........................................................................................

sub name {
  return "Pairwise core SNP distances";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $matrix = Nullarbor::Tabular::load(-file=>$self->indir."/distances.tab", -sep=>"\t");
  
  # want to use vertical layout for labels across
  for my $i ( 1 .. $#{$matrix->[0]} ) {
    $matrix->[0][$i] = "<div class='vertical'>" . $matrix->[0][$i] . "</div>";
  }
  
  return $self->matrix_to_html($matrix, 1, 0);  
}

#...........................................................................................

1;
