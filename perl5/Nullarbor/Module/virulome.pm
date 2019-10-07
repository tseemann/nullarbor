package Nullarbor::Module::virulome;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................

my $MIN_COV = 90;

#...........................................................................................

sub name {
  return "Virulome";
}

#...........................................................................................

sub html {
  my($self) = @_;

  my $infile = $self->indir . "/virulome.tab";
  my $grid = Nullarbor::Tabular::load(-file=>$infile, -sep=>"\t", -header=>1);
  
  for my $row (@$grid) {
    if ($row->[0] =~ m/^#/) {
      # header row
      for my $i (2 .. $#$row) {
         $row->[$i] = "<DIV CLASS='vertical'>".$row->[$i]."</DIV>";
      }
    }
    else {
      # data rows
      $row->[0] =~ s{/[^/]+$}{}; # remove "/resistome.tab"
      for my $i (2 .. $#$row) {
        my($p) = split m";", $row->[$i];
        # apply traffic light system
        if ($p eq '.') {
          $p = $self->pass_fail(-1);
        } 
        elsif ($p <= $MIN_COV) {
          $p = $self->pass_fail(0, "Found % parts: ".$row->[$i]);
        }
        else {
          $p = $self->pass_fail(+1)
        }
        $row->[$i] = $p;
      }
    }
  }
  
  return $self->table_legend("&ge;${MIN_COV}% coverage", "<${MIN_COV}% coverage", "absent") 
        .$self->matrix_to_html($grid);
}

#...........................................................................................

1;
