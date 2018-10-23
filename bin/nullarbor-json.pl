#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use Path::Tiny;
use JSON;
use Cwd qw(realpath);

#-------------------------------------------------------------------
# local modules 

use FindBin;
use lib "$FindBin::RealBin/../perl5";
use Nullarbor::Logger qw(msg err);
use Nullarbor::Module;

#-------------------------------------------------------------------
# constants

my $EXE = "$FindBin::RealScript";
my $TEMPLATE_DIR = "$FindBin::RealBin/../conf";
my $VERSION = '2.0.20181010';
my $AUTHOR = 'Torsten Seemann';
my @CMDLINE = ($0, @ARGV);

#-------------------------------------------------------------------
# parameters

my $verbose = 0;
my $quiet   = 0;
my $name = '';
my $indir = '';
my $outdir = '';
my $preview = 0;

@ARGV or usage();

GetOptions(
  "help"     => \&usage,
  "version"  => \&version, 
  "verbose"  => \$verbose,
  "quiet"    => \$quiet,
  "indir=s"  => \$indir,
) 
or usage();

#.................................................................................
# process parameters

Nullarbor::Logger->quiet($quiet);

msg("Hello", $ENV{USER} || 'stranger');
msg("This is $EXE $VERSION");
msg("Send complaints to $AUTHOR");

$indir or err("Please set the --indir Nullarbor folder");
$indir = realpath($indir);

#-------------------------------------------------------------------
# main() 

my $j = {};

chdir($indir);
my @ids = path("isolates.txt")->lines({chomp=>1});
msg("Identified", scalar(@ids), "isolates.");

for my $id (@ids) {
  # yield
  foreach (path("$id/yield.tab")->lines({chomp=>1})) {
    my($k,$v) = split m/\t/;
    $j->{isolate}{$id}{fastq}{ $k } = $v unless $k eq 'Files';
  };
  # annotation
  my @gff = grep { m/CDS|rRNA|tRNA/ } qx"grep '^$id' $id/contigs.gff | cut -f 3 | sort | uniq -c";
  foreach (@gff) {
    my($count, $ftype) = split ' ';
    $j->{isolate}{$id}{annotation}{$ftype} = $count;
  }
  # resistome
  my $amr = tsv_to_hash("$id/resistome.tab", 4);
  $j->{isolate}{$id}{resistome} = [ sort keys %$amr ];
  # virulome
  my $vir = tsv_to_hash("$id/virulome.tab", 4);
  $j->{isolate}{$id}{virulome} = [ sort keys %$vir ];
  # kraken
  my @species = map { [ split ' ' ] } qx"grep -P '\tS\t' '$id/kraken.tab'";
  $j->{isolate}{$id}{kraken}{ $_->[5].' '.$_->[6] } = $_->[0] for (@species[0..9]);
}

# denovo
my $asm = tsv_to_hash("denovo.tab", 0);
$j->{isolate}{$_}{denovo} = $asm->{$_} for (@ids);

# mlst
my $mlst = tsv_to_hash("mlst.tab", 0, [ 'ID', 'scheme', 'ST' ] );
$j->{isolate}{$_}{mlst} = $mlst->{$_} for (@ids);

# snippycore
my $core = tsv_to_hash('core.txt');
$j->{isolate}{$_}{alignment} = $core->{$_} for (@ids);

# ref
$j->{reference} = tsv_to_hash( 'ref.fa.fai', 0, ['contig','len_bp'] );

# tree
$j->{tree} = path("core.newick")->slurp;

# snp-dists
$j->{snp_distances} = tsv_to_matrix('distances.tab');

msg("Writing JSON to stdout...");

print encode_json($j),"\n";

msg("Done");

#-------------------------------------------------------------------

sub tsv_to_matrix {
  my($fname) = @_;
  my @matrix;
  for my $line ( path($fname)->lines({chomp=>1}) ) {
    push @matrix, [ split m/\t/, $line ];
  }
  return \@matrix;
}

sub tsv_to_hash {
  my($fname, $keycol, $custom_hdr) = @_;
  $keycol ||= 0;
  my $h = {};
  my @hdr;
  @hdr = @$custom_hdr if $custom_hdr;
  for my $line ( path($fname)->lines({chomp=>1}) ) {
    my @row = split m/\t/, $line;
    if (@hdr) {
      my $k = $row[$keycol] or next;
      $k =~ s,/contigs.fa$,,;  # remove '/contigs.fa' suffix
      #next if $k eq 'ref.fa';  # HACK FOR NOW
      for my $i (0 .. $#row) {
        next if $i == $keycol;
        next unless $hdr[$i]; # empty column header
        $h->{$k}{ $hdr[$i] } = $row[$i];
      }
    }
    else {
      @hdr = @row;
    }
  }
  #print Dumper($h); exit;
  return $h;
}

#-------------------------------------------------------------------
sub usage {
  print "NAME\n";
  print "  $EXE $VERSION\n";
  print "SYNOPSIS\n";
  print "  Generate a JSON summary of a Nullabor results folder\n";
  print "AUTHOR\n";
  print "  $AUTHOR\n";
  print "USAGE\n";
  print "  $EXE [options] --indir NULLARBOR_DIR > nullarbor.json\n";
  print "    --indir     Nullarbor result folder\n";
  print "    --quiet     No output\n";
  print "    --verbose   More output\n";
  print "    --version   Print version and exit\n";
  exit;
}

#-------------------------------------------------------------------
sub version {
  print "$EXE $VERSION\n";
  exit;
}

