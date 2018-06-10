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
  push @{$core->[0]}, '%Used', 'Quality';

  # snippy 4.x now has
  # 0           1       2       3         4 		5	6	7	8
  # Isolate	LENGTH	ALIGNED	UNALIGNED VARIANT	MASKED	LOWCOV	%used	quality
   
  # add QC traffic light 
  for my $j (1 .. $#$core) {
    my $row = $core->[$j];
    my $used = sprintf "%.2f", 100 * $row->[2] / $row->[1];
    push @$row, $used;
    push @$row, $self->pass_fail( $used < 70 ? -1 : $used < 90 ? 0 : +1 );
  }

  return $self->matrix_to_html($core);
}

#...........................................................................................

1;

