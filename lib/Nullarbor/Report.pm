package Nullarbor::Report;
use Moo;

use Nullarbor::Logger qw(msg err);
use Data::Dumper;
use File::Copy;

#.................................................................................

sub generate {
  my($self, $indir, $outdir) = @_;

  # Heading
  open my $fh, '>', "$outdir/index.md";
  print $fh "#MDU Report: $indir\n";

  # MLST
  my $mlst = load_tabular(-file=>"$indir/mlst.csv", -sep=>"\t", -header=>1);
#  print STDERR Dumper($mlst);
  
  my @id;
  foreach (@$mlst) {
    $_->[0] =~ s{/contigs.fa}{};
    push @id, $_->[0];
  }
  shift @id;
#  print STDERR Dumper(\@id);

  print $fh "##MLST\n";
  $mlst->[0][0] = 'Isolate';
  print $fh table_to_markdown($mlst, 1);
  
  
  # Yields
  print $fh "##WGS\n";
  my @wgs;
  my $first=1;
  for my $id (@id) {
    my $t = load_tabular(-file=>"$indir/$id/yield.clean.csv", -sep=>"\t");
    if ($first) {
      $t->[0][0] = 'Isolate';
      push @wgs, [ map { $_->[0] } @$t ];
      $first=0;
    }
    $t->[0][1] = $id;
    push @wgs, [ map { $_->[1] } @$t ];
  }
#  print Dumper(\@wgs);
  print $fh table_to_markdown(\@wgs, 1);
    
  # Species ID
  print $fh "##Sequence identification\n";
  my @spec;
  push @spec, [ 'Isolate', 'Predicted species' ];
  $first=1;
  for my $id (@id) {
    my $t = load_tabular(-file=>"$indir/$id/kraken.csv", -sep=>"\t");
    my @s = grep { $_->[3] eq 'S' or $_->[3] eq '-' && $_->[0] < 90 } @$t;
    push @spec, [ $id, $s[0][5] ];
  }
#  print Dumper(\@spec);
  print $fh table_to_markdown(\@spec, 1);

  # Assembly
  print $fh "##Assembly\n";
  my $ass = load_tabular(-file=>"$indir/assembly.csv", -sep=>"\t", -header=>1);
#  print STDERR Dumper($ass);
  $ass->[0][0] = 'Isolate';
  $ass->[0][1] = 'Contigs';
  map { $_->[0] =~ s{/contigs.fa}{} } @$ass;
  print $fh table_to_markdown($ass,1);
  
  # ABR
  print $fh "##Antibiotic Resistance\n";
  my %abr;
  for my $id (@id) {
    $abr{$id} = load_tabular(-file=>"$indir/$id/abricate.csv", -sep=>"\t",-header=>1, -key=>4);
  }
#  print STDERR Dumper(\%abr);
  my @abr;
  push @abr, [ qw(Isolate Genes) ];
  for my $id (@id) {
    my @x = sort keys %{$abr{$id}};
    @x = 'n/a' if @x==0;
    push @abr, [ $id, join( ',', @x) ];
  }
  print $fh table_to_markdown(\@abr, 1);

  # Reference Genome
  print $fh "##Reference genome\n";
  my $r = load_tabular(-file=>"fa -f $indir/ref.fa |", -sep=>"\t");
  my @ref;
  push @ref, [ qw(Sequence Length) ];
  for my $row (@$r) {
    push @ref, [ $row->[0], $row->[2] ] if @$row == 3;
  }
#  print STDERR Dumper($r, \@ref);
  print $fh table_to_markdown(\@ref, 1);
 
  # Reference Genome
  print $fh "##Core SNP tree\n";
  copy("$indir/tree.gif", "$outdir/tree.gif");
  print $fh "![Core tree](tree.gif)\n";
}

#.................................................................................

sub table_to_markdown {
  my($table, $header) = @_;
  my $res = "\n";
  my $row_no=0;
  for my $row (@{$table}) {
    $res .= join(' | ', @$row)."\n";
    if ($header and $row_no++ == 0) {
      $res .= join(' | ', map { '---' } @$row)."\n";
    }
  }
  return $res."\n";
}

#.................................................................................
# EVENTUALLY!:
# -file     | filename to load
# -sep      | column separator eg. "\t" ","  (undef = auto-detect)
# -header   | 1 = yes,  0 = no,  undef = auto-detect '#' at start
# -comments | undef = none, otherwise /pattern/ to match
# -key      | undef = return list-of-lists  /\d+/ = column,  string = header column

sub load_tabular {
  my(%arg) = @_;
 
  my $me = (caller(0))[3];
  my $file = $arg{'-file'} or err("Missing -file parameter in $me");
  my $sep = $arg{'-sep'} or err("Please specify column separator in $me");

  my @hdr;
  my $key_col;
  my $res;
  my $row_no=0;

  open TABULAR, $file or err("Can't open $file in $me");
  while (<TABULAR>) {
    chomp;
    my @col = split m/$sep/;
    if ($row_no == 0 and $arg{'-header'}) {
      @hdr = @col;
      if (not defined $arg{'-key'}) {
        $key_col = undef;
      }
      elsif ($arg{'-key'} =~ m/^(\d+)$/) {
        $key_col = $1;
        $key_col < @hdr or err("Key column $key_col is beyond columns: @hdr");
      }
      else {
        my %col_of = (map { ($hdr[$_] => $_) } (0 .. $#hdr) );
        $key_col = $col_of{ $arg{'-key'} } or err("Key column $arg{-key} not in header: @hdr");
      }
    }

    if (not defined $key_col) {
      push @{$res}, [ @col ];
    }
    elsif ($row_no != 0) {
      $res->{ $col[$key_col] } = { map { ($hdr[$_] => $col[$_]) } 0 .. $#hdr };
    }
    $row_no++;
  }
  close TABULAR;
  return $res;
}

1;

