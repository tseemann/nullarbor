#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);
use Spreadsheet::Read;
use Data::Dumper;
use Cwd;

my $id_re = '\b(\d{4}-\d{5})\b';
my $read_re = '_R?([12])(?:_\d+)?.f';
my $in  = '';
my $dir = '/mnt/seq/MDU/READS';
my $out = 'samples.tab';
my $longid = 0;
my $verbose = 0;

sub usage {
  print "$0 [--verbose] [--longid] [--fastqdir $dir] [--out $out] --in jobdetails.xlsx\n";
  exit;
}

@ARGV or usage();

GetOptions(
  "help"        => \&usage,
  "verbose!"    => \&verbose,
  "in=s"        => \$in,
  "fastqdir=s"  => \$dir,
  "out=s"       => \$out,
  "longid!"    => \$longid,
  "id_regexp=s"    => \$id_re,
  "read_regexp=s"    => \$read_re,
) 
or usage();

if (!$in and @ARGV > 0) {
  $in = shift @ARGV;
  print STDERR "Guessing --in $in\n";
}

$in or die "need ID file with --in job.xls";
-r $in or die "can't read ID file '$in'";

$dir or die "need top-level folder containing FASTQ files with --dir";
-d $dir or die "--dir '$dir' is not a directory";

$out or die "need --out file to save results to";

# compile regexps
$id_re = qr"$id_re";
$read_re = qr"$read_re";

print STDERR "Scanning '$in' for MDU sample IDs...\n";

my $book = ReadData( $in, cells=>0, strip=>3, attr=>1 );
#print Dumper($book); exit;
my @row = Spreadsheet::Read::rows($book->[1]);
my %id;
for my $row (@row) {
  my $line = join(' ', grep { defined $_ } @$row); 
  if ($line =~ $id_re) {
    my $ID = $1;
    $line =~ s/\s+/--/g;
    $line =~ s/[_-]+$//;
    $line =~ s/^[_-]+//;
    $id{$ID} = $line;
  }
}

printf STDERR "Found %d sample IDs:\n", scalar(keys %id);

if (0 == keys %id) {
  print STDERR "ERROR: no IDs found in '$in'\n";
  exit -1;
}

print STDERR map { "$_\n" } sort keys %id if $verbose;

print STDERR "Scanning '$dir' for read files...\n";

my %want_id = (map { ($_ => 1) } keys %id);
my %sample;

open DIR, "find $dir -type f -name '*.f*q.gz' |";
while (my $file = <DIR>) {
  chomp $file;
  if ($file =~ $id_re and exists $want_id{$1}) {
    my $id = $1;
    my(undef, undef, $name) = File::Spec->splitpath($file);
    if ($name =~ $read_re) {
      my $read = $1;
#      print STDERR "$id $read\n";
      $sample{$id}{$read} = abs_path($file);
      print STDERR "Found $id $read : $file\n" if $verbose;
    }
    else {
      print STDERR "WARNING: found $id but not $read_re in $name\n";
    }
  }
}

print STDERR "Creating output file: $out\n";
open OUT, '>', $out;

#use Data::Dumper;
#print STDERR Dumper(\%id);

for my $id (sort keys %id) {
  if (exists $sample{$id}{1} and exists $sample{$id}{2}) {
    my $label = $longid ? $id{$id} : $id;
    print STDERR "$id - both reads found, labelling as '$label'\n";
    printf OUT join("\t", $label, $sample{$id}{1}, $sample{$id}{2})."\n";
  }
  elsif (!exists $sample{$id}{1} and !exists $sample{$id}{2}) {
    print STDERR "$id - NO READ FOUNDS !!!\n";
  }
  elsif (!exists $sample{$id}{1}) {
    print STDERR "$id - MISSING Read 1 FILE !!!\n";
  }
  elsif (!exists $sample{$id}{2}) {
    print STDERR "$id - MISSING Read 2 FILE !!!\n";
  }
  else {
    print STDERR "$id - THIS LINE SHOULD NEVER BE REACHED\n";
  }
}

print STDERR "Result in '$out'\n";
print STDERR "Done.\n";

my $name = qx(basename `pwd`);
chomp $name;
my $cmd = "nullarbor.pl --name $name --outdir nullarbor --input samples.tab --cpus 4 --mlst FIXME --ref FIXME";

print STDERR "Your next command is probably this:\n$cmd\n";


