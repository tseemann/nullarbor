package Nullarbor::Tabular;

use base Exporter;
#@EXPORT_OK = qw(load_as_hash);

use Nullarbor::Logger qw(msg err);
use List::Util qw(sum min max);
use Data::Dumper;

#.................................................................................

sub column_average {
  my($matrix, $col, $format) = @_;
  $col ||= 0;
  $format ||= "%f";
  my $nrows = $#$matrix;
  my $sum = sum( map { $matrix -> [$_] [$col] } 1 .. $nrows ); # skip header
  return sprintf $format, $sum/$nrows;
}
                            
#.................................................................................
# EVENTUALLY!:
# -file     | filename to load
# -sep      | column separator eg. "\t" ","  (undef = auto-detect)
# -header   | 1 = yes,  0 = no,  undef = auto-detect '#' at start
# -comments | undef = none, otherwise /pattern/ to match
# -key      | undef = return list-of-lists  /\d+/ = column,  string = header column

sub load {
  my(%arg) = @_;
 
  my $me = (caller(0))[3];
  my $file = $arg{'-file'} or err("Missing -file parameter in $me");
  my $sep = $arg{'-sep'} or err("Please specify column separator in $me");

  my @hdr;
  my $key_col;
  my $res;
  my $row_no=0;

  open my $TABLE, $file or err("Can't open $file in $me");
  while (<$TABLE>) {
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
#      this code fails when there are duplicate keys!!! eg. genes in abricate.
#      $res->{ $col[$key_col] } = { map { ($hdr[$_] => $col[$_]) } 0 .. $#hdr };
      push @{ $res->{ $col[$key_col] } } , { map { ($hdr[$_] => $col[$_]) } 0 .. $#hdr };
    }
    $row_no++;
  }
  close $TABLE;
  return $res;
}

#.................................................................................
# EVENTUALLY!: use Text::CSV 

sub save {
  my($outfile, $matrix, $sep) = @_;
  $sep ||= "\t";
  open my $TABLE, '>', $outfile;
  for my $row (@$matrix) {
    print $TABLE join($sep, @$row),"\n";
  }
  close $TABLE;
}

#.................................................................................

sub load_as_hash {
  my($infile, $key_col, $val_col, $sep, $skip) = @_;
  $key_col ||= 0;
  $val_col ||= 1;
  $sep ||= "\t";
  my $result = {};
  open my $TABLE, '<', $infile;
  while (<$TABLE>) {
    next if $skip and m/$skip/;
    chomp;
    my @row = split m/$sep/;
    $result->{ $row[ $key_col ] } = $row[ $val_col ];
  }
  close $TABLE;
  return $result;
}

#.................................................................................

1;

