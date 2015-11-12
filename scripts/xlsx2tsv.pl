#!/usr/bin/env perl
use warnings;
use strict;
use Spreadsheet::Read;
use Data::Dumper;

my(@Options, $verbose, $sep, $informat);
setOptions();

my $book = ReadData( $ARGV[0], cells=>0, strip=>1 );

my @row = Spreadsheet::Read::rows($book->[1]);

for my $row (@row) {
  my @r = map { $_ || '' } @$row;
  print join($sep, @r),"\n";
}

#----------------------------------------------------------------------
# Option setting routines

sub setOptions {
  use Getopt::Long;

  @Options = (
    {OPT=>"help",    VAR=>\&usage,             DESC=>"This help"},
    {OPT=>"verbose!",  VAR=>\$verbose, DEFAULT=>0, DESC=>"Verbose output"},
#    {OPT=>"informat=s",  VAR=>\$informat, DEFAULT=>"xlsx", DESC=>"Input format: xls xlsx csv ods sxc"},
    {OPT=>"sep=s",  VAR=>\$sep, DEFAULT=>"\t", DESC=>"Output separator"},
  );

  #(!@ARGV) && (usage());

  &GetOptions(map {$_->{OPT}, $_->{VAR}} @Options) || usage();

  # Now setup default values.
  foreach (@Options) {
    if (defined($_->{DEFAULT}) && !defined(${$_->{VAR}})) {
      ${$_->{VAR}} = $_->{DEFAULT};
    }
  }
}

sub usage {
  print "Usage: $0 [options] [<] file.xlsx > file.csv\n";
  foreach (@Options) {
    printf "  --%-13s %s%s.\n",$_->{OPT},$_->{DESC},
           defined($_->{DEFAULT}) ? " (default '$_->{DEFAULT}')" : "";
  }
  exit(1);
}
 
#----------------------------------------------------------------------
