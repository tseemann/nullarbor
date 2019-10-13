package Nullarbor::Module::mashdist;
use Moo;
extends 'Nullarbor::Module';

#...........................................................................................

sub name {
  return "Pairwise MASH sketch distances";
}

#...........................................................................................

sub html {
  my($self) = @_;
  
  my $matrix = Nullarbor::Tabular::load(-file=>$self->indir."/preview.mat", -sep=>"\t");
  my $NTAXA = @$matrix - 1;
 
  # copy col[0] labels to row[0]
  for my $i ( 1 .. $NTAXA ) {
    $matrix->[0][$i] = "<div class='vertical'>" . $matrix->[$i][0] . "</div>";
  }
  $matrix->[0][0] = 'Isolate';

  # second param '1' means a plain table, don't use DataTables  
  return $self->matrix_to_html($matrix, 1);  
}

#...........................................................................................

1;
