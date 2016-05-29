package Nullarbor::Module::snpdist;
use Moo;
extends 'Nullarbor::Module';

use List::Util qw(min max);

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

  # collect upper triangle of snp distances, skip diagonal
  my @dist;
  for my $j ( 2 .. $#$matrix ) {
    for my $i ( $j+1 .. $#{$matrix->[$j]} ) {
      push @dist, $matrix->[$j][$i];
    }
  }
  my $dist_js = join(',', @dist);
  my $max_dist = max(@dist);

  # produce Plotly.js javascript  
  my $html = "
<div id='snpdist-histogram'>
</div>
<script>
var nums = [ $dist_js ];
var data = [ { 
  type: 'histogram',
  x: nums, 
  autobinx: false,
  xbins: { start: 0, end: $max_dist, size: 1 },
} ];
var layout = {
  title: 'Pairwise core SNP distance histogram',
  xaxis: { title: 'SNP distance' },
  yaxis: { title: 'Frequency' },
};
Plotly.newPlot('snpdist-histogram', data, layout);
</script>
";
  
  return $html . $self->matrix_to_html($matrix);  
}

#...........................................................................................

1;
