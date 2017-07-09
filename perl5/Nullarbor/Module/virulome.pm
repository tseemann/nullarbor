package Nullarbor::Module::virulome;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................

sub name {
  return "Virulome";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
  my @id = @{$self->isolates};

  my %abr;
  for my $id (@id) {
    $abr{$id} = Nullarbor::Tabular::load(-file=>"$indir/$id/virulome.tab", -sep=>"\t", -header=>1, -key=>4); # 4 = "GENE"
  }
#  print STDERR Dumper(\%abr);

#  my $csv_fn = "$name.resistome.csv";
  my $ABSENT = '.';
  my %gene;
  map { $gene{$_}++ } (map { (keys %{$abr{$_}}) } @id);
  my @gene = sort { $a cmp $b } keys %gene;
  my @grid = ( [ 'Isolate', 'Found', @gene ] ); # for HTML
  my @grid2 = ( [ @{$grid[0]} ] );              # for CSV
  
  for my $id (@id) {
    my @abr;
    my @abr2;
    for my $g (@gene) {
      my $hit = $ABSENT;
      my $hit2 = $ABSENT;
      if ($abr{$id}{$g}) {
        my @hits = @{ $abr{$id}{$g} };
        $hit = @hits == 1 && int($hits[0]->{'%COVERAGE'}) >= 95
             ? $self->pass_fail( +1 ) 
             : $self->pass_fail( 0, join(' + ', map { int($_->{'%COVERAGE'}).'%' } @hits) );
#          $hit = join("+", 
#            map { percent_cover( int $_->{'%COVERAGE'}, 100) } 
#              sort { $b->{'%COVERAGE'} <=> $a->{'%COVERAGE'} } @hits
#          );
        $hit2 = join("+", map { int $_->{'%COVERAGE'} } @hits);
      }
      push @abr, $hit;
      push @abr2, $hit2;
    }      
    my $found = scalar( grep { $_ ne $ABSENT } @abr );
    push @grid,  [ $id, $found, @abr ];
    push @grid2, [ $id, $found, @abr2 ];
  }
  
  # add CSS to help rotate the labels to this big table!
  my $W = scalar( @{$grid[0]} );
  for my $i (2 .. $W-1) {
    $grid[0][$i] = "<DIV CLASS='vertical'>$grid[0][$i]</DIV>";
  }
  
  return $self->matrix_to_html(\@grid);

#  save_tabular("$outdir/$csv_fn", \@grid2, ",");
}

#...........................................................................................

1;

