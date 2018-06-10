package Nullarbor::Module::snpdensity;
use Moo;
extends 'Nullarbor::Module';

use List::Util qw(min max sum);

#...........................................................................................

sub name {
  return "Core SNP density";
}

#...........................................................................................

sub html {
  my($self) = @_;
  
  my $matrix = Nullarbor::Tabular::load(-file=>$self->indir."/core.tab", -sep=>"\t");
  my $fai = load_fai($self->indir."/ref.fa.fai");

  my %offset;
  my $pos=0;
  for my $entry (@$fai) {
    $offset{ $entry->[0] } = $pos;
    $pos += $entry->[1];
  }

  my @x;
  for my $row (@$matrix) {
    my($seqid,$pos) = ($row->[0], $row->[1]);
    next unless $pos =~ m/^\d+$/;
    push @x, $pos + $offset{ $seqid };
  }
#  @x = sort { $a <=> $b } @x;
  my $max = max(@x);
  my $num = scalar(@x);
#  my $max = $x[-1];
  my $xs = join(',', @x);
  my $len = sum( map { $_->[1] } @$fai );
  
  # produce Plotly.js javascript  
  my $html = "
<div id='snpdensity-histogram'>
</div>
<script>
var nums = [ $xs ];
var data = [ { 
  type: 'histogram',
  x: nums, 
//  autobinx: false,
//  xbins: { start: 0, end: $max, size: 1 },
} ];
var layout = {
  title: '$num SNPs across $len bp',
  xaxis: { title: 'Genome position' },
  yaxis: { title: 'SNPs' },
};
Plotly.newPlot('snpdensity-histogram', data, layout);
</script>
";
  
  return $html;  
}

#...........................................................................................

sub load_fai {
  my($fai) = @_;
  my $idx;
  open FAI, '<', $fai;
  while (<FAI>) {
    my($seqid, $len) = split m/\t/;
    push @$idx, [ $seqid, $len ];
  }
  return $idx;
}


#...........................................................................................

1;
