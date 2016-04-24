package Nullarbor::Module::core;
use Moo;
extends 'Nullarbor::Module';

use Nullarbor::Tabular;
use Data::Dumper;
use List::Util qw(sum);

#...........................................................................................

sub name {
  return "Core genome";
}

#...........................................................................................

sub html {
  my($self) = @_;
  
  my $core = Nullarbor::Tabular::load(-file=>$self->indir."/core.txt", -sep=>"\t");
  $core->[0][0] = 'Isolate';
  push @{$core->[0]}, 'Quality';
  
  # add bottom average row
  my $AC = Nullarbor::Tabular::column_average($core, 3, "%.2f");
  push @{$core}, [
    "AVERAGE",
    Nullarbor::Tabular::column_average($core, 1, "%d"),
    $core->[-1][2], # refsize
    $AC,
  ];

  # add QC
  for my $row (1 .. $#$core) {
    my $C = $core->[$row][3];
    push @{$core->[$row]}, $self->pass_fail( $C < 0.5*$AC ? -1 : $C < 0.9*$AC ? 0 : +1 );
  }

  return $self->matrix_to_html($core);
}

#...........................................................................................

1;

