#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Spec qw(catfile);

#-------------------------------------------------------------------
# local modules 

use FindBin;
use lib "$FindBin::Bin/../lib";
use Nullarbor::IsolateSet;
use Nullarbor::Logger qw(msg err);
use Nullarbor::Report;

#-------------------------------------------------------------------
# constants

my $EXE = "$FindBin::RealScript";
my $VERSION = '0.2';
my $AUTHOR = 'Torsten Seemann <torsten.seemann@gmail.com>';

#-------------------------------------------------------------------
# parameters

@ARGV or usage();

my $verbose = 0;
my $quiet   = 0;
my $ref = '';
my $mlst = '';
my $input = '';
my $outdir = '';
my $cpus = 8;
my $force = 0;
my $run = 0;
my $report = 0;
my $indir = '';
my $name = '';

GetOptions(
  "help"     => \&usage,
  "version"  => \&version, 
  "verbose"  => \$verbose,
  "quiet"    => \$quiet,
  "mlst=s"   => \$mlst,
  "ref=s"    => \$ref,
  "cpus=i"   => \$cpus,
  "input=s"  => \$input,
  "outdir=s" => \$outdir,
  "force!"   => \$force,
  "run!"     => \$run,
  "report!"  => \$report,
  "indir=s"  => \$indir,
  "name=s"   => \$name,
) 
or usage();

Nullarbor::Logger->quiet($quiet);

msg("Hello", $ENV{USER} || 'stranger');
msg("This is $EXE $VERSION");
msg("Send complaints to $AUTHOR");

if ($report) {
  $indir or err("Please ser the --indir folder to a $EXE output folder");
  $outdir or err("Please set the --outdir output folder.");
  $name or err("Please specify a report --name");
  make_path($outdir) unless -f $outdir;
  Nullarbor::Report->generate($indir, $outdir, $name);
  exit;
}

my %make;
my $make_target = '$@';
my $make_dep = '$<';
my $make_deps = '$^';

$name or err("Please provide a --name for the project.");
$name =~ m{/|\s} and err("The --name is not allowed to have spaces or slashes in it.");

$outdir or err("Please provide an --outdir folder.");
if (-d $outdir) {
  if ($force) {
    msg("Re-using existing folder: $outdir");
#    msg("Forced removal of existing --outdir $outdir");
#    remove_tree($outdir);
  }
  else {
    err("The --outdir '$outdir' already exists. Try using --force");
  }
}
$outdir = File::Spec->rel2abs($outdir);
msg("Making output folder: $outdir");
make_path($outdir); 

-r $ref or err("Can not read reference '$ref'");
$ref = File::Spec->rel2abs($ref);
msg("Using reference genome: $ref");

my %scheme = ( map { $_=>1 } split ' ', qx(mlst --list) );
msg("Found", scalar(keys %scheme), "MLST schemes");
$mlst or err("Please provide an --mlst <scheme> from this list:\n", sort keys %scheme);
err("Invalid --mlst '$mlst'") if ! exists $scheme{$mlst}; 
msg("Using scheme: $mlst");

$input or err("Please specify an dataset with --input <dataset.tab>");
-r $input or err("Can not read dataset file '$input'");
my $set = Nullarbor::IsolateSet->new();
$set->load($input);
msg("Loaded", $set->num, "isolates:", $set->ids);

my $REF = 'ref.fa';
my $R1 = "R1.fq.gz";
my $R2 = "R2.fq.gz";
my $CTG = "contigs.fa";
my $zcat = 'gzip -f -c -d';

# Makefile logic

my @PHONY = [ qw(folders yields abricate kraken) ] ;

$make{'.PHONY'} = { 
  DEP => \@PHONY, 
};

$make{all} = { 
  DEP => [ 'report/index.html' ],
};

$make{'report/index.html'} = {
  DEP => 'report/index.md',
  CMD => "pandoc --from markdown_github --to html --css 'nullarbor.css' $make_dep > $make_target"
};

$make{'report/index.md'} = {
  DEP => [ $REF, @PHONY, qw(mlst.csv assembly.csv tree.gif snps.csv) ],
  CMD => "$FindBin::Bin/nullarbor.pl --name $name --report --indir $outdir --outdir $outdir/report",
};
  
$make{$REF} = { 
  DEP => $ref, 
  CMD => "cp $make_dep $make_target",
};


for my $s ($set->isolates) {
  msg("Preparing rules for isolate:", $s->id);
  my $dir = File::Spec->rel2abs( File::Spec->catdir($outdir, $s->id) );
  $s->folder($dir);
  my $id = $s->id;
  my @reads = @{$s->reads};
  @reads != 2 and err("Sample '$id' only has 1 read, need 2 (paired).");
  my @clipped = ("$id/$R1", "$id/$R2");

#  make_path($dir);
  $make{"$id"} = {
    CMD => [ "mkdir -p $make_target" ],
  };
  $make{"$id/yield.dirty.csv"} = {
    DEP => [ @reads ],
    CMD => "fq --quiet --ref $ref @reads > $make_target",
  };
  $make{"$id/yield.clean.csv"} = {
    DEP => [ @clipped ],
    CMD => "fq --quiet --ref $ref $make_deps > $make_target",
  };
  $make{$clipped[0]} = {
    DEP => [ @reads ],
    CMD => [ "skewer --quiet -t $cpus -n -l 50 -q 10 -z -o $id/clipped @reads",
             "mv $id/clipped-trimmed-pair1.fastq.gz $id/$R1",
             "mv $id/clipped-trimmed-pair2.fastq.gz $id/$R2", ],
  };
  # we need this special rule to handle the 'double dependency' problem
  # http://www.gnu.org/software/automake/manual/html_node/Multiple-Outputs.html#Multiple-Outputs
  $make{$clipped[1]} = { 
    DEP => [ $clipped[0] ],
  };
  $make{"$id/$CTG"} = {
    DEP => [ @clipped ],
    CMD => [ 
      "megahit -m 1E10 -l 650 --out-dir $id --input-cmd '$zcat $make_deps' --cpu-only -t $cpus --k-min 31 --k-max 31 --min-count 3",
      "mv $id/final.contigs.fa $make_target",
      "mv $id/log $id/megahit.log",
      "rm -r $id/tmp $id/done $id/opts.txt",
#      "minia -in $clipped[0] -in $clipped[1] -verbose 0 -nb-cores $cpus -out-dir $id -out $id/minia -kmer-size 31 -abundance-min 3 -fasta-line 60".
#     " && mv $id/minia.contigs.fa $make_target",
#     "rm $id/minia.h5" 
    ],
  };
  $make{"$id/kraken.csv"} = {
    DEP => [ @clipped ],
    CMD => "kraken --threads $cpus --preload --quick --paired @clipped | kraken-report > $make_target",
  };
  $make{"$id/abricate.csv"} = {
    DEP => "$id/$CTG",
    CMD => "abricate $make_deps > $make_target",
  };
}

$make{"folders"} = { 
  DEP => [ $set->ids ],
};

$make{"yields"} = { 
  DEP => [ map { ("$_/yield.dirty.csv", "$_/yield.clean.csv") } $set->ids ],
};

$make{"abricate"} = { 
  DEP => [ map { "$_/abricate.csv" } $set->ids ],
};

$make{"kraken"} = { 
  DEP => [ map { "$_/kraken.csv" } $set->ids ],
};

#$make{'mlst'} = { 
#  DEP => 'mlst.csv',
#};

$make{"mlst.csv"} = { 
  DEP => [ map { "$_/$CTG" } $set->ids ],
  CMD => "mlst --scheme $mlst $make_deps > $make_target" ,
};

$make{"assembly.csv"} = { 
  DEP => [ map { "$_/$CTG" } $set->ids ],
  CMD => "fa -t -e $make_deps > $make_target" ,
};

my $wtree = "wombac/core.tree";
$make{"wombac"} = { DEP => $wtree };
$make{$wtree} = {
  DEP => [ $REF, map { ("$_/$R1", "$_/$R2") } $set->ids ],
  CMD => "wombac --force --ref $REF --outdir wombac --run --ref $REF ".join(' ',$set->ids),
};

$make{'tree.svg'} = {
  DEP => 'wombac/core.tree',
#  CMD => "figtree -graphic GIF -width 1024 -height 1024 $make_dep $make_target",
  CMD => "nw_display -S -s -w 1024 -l 'font-size:12' -i 'opacity:0' -b 'opacity:0' $make_dep > $make_target",
};

$make{'tree.gif'} = {
  DEP => 'tree.svg',
  CMD => "convert $make_dep $make_target",
};

$make{'snps.csv'} = {
  DEP => 'wombac/core.aln',
  CMD => "afa-pairwise.pl $make_dep > $make_target",
};

my $ptree = "parsnp/parsnp.tree";
$make{"parsnp"} = { DEP => $ptree };
$make{$ptree} = {
  DEP => [ $REF, map { "$_/$CTG" } $set->ids ],
  CMD => [ "mkdir -p parsnp/genomes",
           (map { "ln -sf $outdir/$_/contigs.fa $outdir/parsnp/genomes/$_.fa" } $set->ids),
           "parsnp -p $cpus -c -d parsnp/genomes -r $ref -o parsnp",
         ],
};



#print Dumper(\%make);
my $makefile = "$outdir/Makefile";
open my $make_fh, '>', $makefile or err("Could not write $makefile");
write_makefile(\%make, $make_fh);
if ($run) {
  exec("make -C $outdir") or err("Could not run pipeline's Makefile");
}
else {
  #msg("Run the pipeline with: nohup nice make -C $outdir 1> $outdir/log.out $outdir/log.err");
  msg("Run the pipeline with: nice make -C $outdir");
}
msg("Done");

#----------------------------------------------------------------------
sub write_makefile {
  my($make, $fh) = @_;
  $fh = \*STDOUT if not defined $fh;
  
  print $fh "SHELL := /bin/bash\n";
  
  for my $target ('all', sort grep { $_ ne 'all' } keys %$make) {
    my $dep = $make->{$target}{DEP};
    $dep = ref($dep) eq 'ARRAY' ? (join ' ', @$dep) : $dep;
    $dep ||= '';
    print $fh "$target: $dep\n";
    if (my $cmd = $make->{$target}{CMD}) {
      my @cmd = ref $cmd eq 'ARRAY' ? @$cmd : ($cmd);
      print $fh map { "\t$_\n" } @cmd;
    }
  }
}

#-------------------------------------------------------------------
sub usage {
  print "USAGE\n";
  print "(1) Analyse samples\n";
  print "  $EXE [options] --mlst SCHEME --ref REF.FA --input SAMPLES.TAB --outdir DIR\n";
  print "    --force     Nuke --outdir\n";
  print "    --cpus      Number of CPUs to use\n";
  print "    --quiet     No output\n";
  print "    --verbose   More output\n";
  print "    --version   Tool version\n";
  print "(2) Generate report\n";
  print "  $EXE [options] --indir DIR --outdir WEBDIR --name JOBNAME\n";
  print "    --version   Tool version\n";
  exit;
}

#-------------------------------------------------------------------
sub version {
  print "$EXE $VERSION\n";
  exit;
}
