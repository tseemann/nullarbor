package Nullarbor::Module::mlst;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use List::Util qw(sum max min);

#...........................................................................................

sub name {
  return "MLST";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
#  my $ids = $self->isolates;

  my $mlst_legend = [
    [ "Legend", "Meaning" ],
    [ "(n)", "exact intact allele" ],
    [ "(~n)", "novel allele similar to n" ],
    [ "(n?)", "partial match to known allele" ],
    [ "(n,m)", "multiple alleles" ],
    [ "(-)", "allele missing" ],
  ];

# LEGACY
if (0) {
  my $mlst = Nullarbor::Tabular::load(-file=>"$indir/mlst.tab", -sep=>"\t", -header=>1);
#  print STDERR Dumper($mlst);
  
  for my $row (@$mlst) {
    $row->[0] =~ s{/contigs.fa}{};
    $row->[0] =~ s/ref.fa/Reference/;
    # move ST column to end to match MDU LIMS
    my($ST) = splice @$row, 2, 1;
    my $missing = sum( map { $row->[$_] eq '-' ? 1 : 0 } (1 .. $#$row) );
    push @$row, $ST;
#    push @$row, "**${ST}**";
#    push @$row, pass_fail( $missing==0 && $ST ne '-' ? +1 : $missing <= 1 ? 0 : -1 );
  }
  $mlst->[0][0] = 'Isolate';
  $mlst->[0][-1] = 'ST';
}

  #...........................................................................................
  # MLST
  
  my $mlst2 = Nullarbor::Tabular::load(-file=>"$indir/mlst.tab", -sep=>"\t", -header=>0);

  # find maximum width (#columns) amongst the rows  
  my $width = max( map { scalar(@$_) } @$mlst2 );

  for my $row (@$mlst2) {
    $row->[0] =~ s{/contigs.fa}{};
    $row->[0] =~ s/ref.fa/Reference/;
    my $ST = $row->[2];
#    my $missing = $row->[2] eq '-' ? 1E9 : sum( map { $row->[$_] =~ m/[-~?]/ ? 1 : 0 } (3 .. $#$row) );
#    my $missing = sum( map { $row->[$_] =~ m/[-?]/ ? 1 : 0 } (3 .. $#$row) ); # not ~
    my $missing = $row->[2] eq '-' ? 1E9 : sum( map { $row->[$_] =~ m/[-?]/ ? 1 : 0 } (3 .. $#$row) ); # not ~
#    print Dumper($row, $missing);
    for my $i (3 .. $#$row) {
      my $g = $row->[$i];
      $g =~ s/^_//; # fix bold bug for alleles ending in _ !
      $g =~ s/_$//;
      my $class = $g =~ m/[-?,]/ ? "missing" : $g =~ m/~/ ? "novel" : "known";
      $row->[$i] = "<SPAN CLASS='allele $class'>$g</SPAN>";
    }
    while (@$row < $width) {
      push @$row, '.';  # padding
    }
#    print STDERR "ST=$ST missing=$missing @$row\n";
    push @$row, $self->pass_fail( $ST ne '-' ? +1 : $missing == 0 ? 0 : -1 );
  }

  # add header
  unshift @{$mlst2}, [ "Isolate", "Scheme", "Sequence<BR>Type", ("Allele")x($width-3), "Quality" ];

  # these are the 'old style' tables for download ... FIXME (MDU legacy)
#  save_tabular("$outdir/$name.mlst.csv", $mlst, ",");   
#  print $fh "Download: [$name.mlst.csv]($name.mlst.csv)\n";
  
  return $self->matrix_to_html($mlst2);

#    return $self->matrix_to_html(\@wgs, 1);
}

#...........................................................................................

1;

