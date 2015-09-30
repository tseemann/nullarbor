#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Spec qw(catfile);
use YAML::Tiny;

#-------------------------------------------------------------------
# local modules 

use FindBin;
use lib "$FindBin::RealBin/../perl5";
use Nullarbor::IsolateSet;
use Nullarbor::Logger qw(msg err);
use Nullarbor::Report;
use Nullarbor::Requirements qw(require_exe require_perlmod require_version);

#-------------------------------------------------------------------
# constants

my $EXE = "$FindBin::RealScript";
my $VERSION = '0.6';
my $AUTHOR = 'Torsten Seemann <torsten.seemann@gmail.com>';

#-------------------------------------------------------------------
# parameters

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
my $conf_file = "$FindBin::RealBin/../conf/nullarbor.conf";

@ARGV or usage();

GetOptions(
  "help"     => \&usage,
  "version"  => \&version, 
  "verbose"  => \$verbose,
  "quiet"    => \$quiet,
  "conf=s"   => \$conf_file,
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

require_exe( qw'prokka roary kraken snippy mlst abricate megahit nw_order nw_display trimal FastTree' );
require_exe( qw'fq fa afa-pairwise.pl' );
require_exe( qw'convert pandoc head cat install env' );
require_perlmod( qw'XML::Simple Data::Dumper Moo Spreadsheet::Read SVG::Graph Bio::SeqIO File::Copy Time::Piece YAML::Tiny' );

require_version('megahit', 1.0);
require_version('snippy', 2.5);
require_version('prokka', 1.10);
require_version('roary', 3.0);

my $cfg;
if (-r $conf_file) {
  my $yaml = YAML::Tiny->read( $conf_file );
  $cfg = $yaml->[0];
#  print Dumper($cfg);
  msg("Loaded YAML config: $conf_file");
  msg("Options set:", keys %$cfg);
}
else {
  msg("Could not read config file: $conf_file");
}

if ($report) {
  $indir or err("Please set the --indir folder to a $EXE output folder");
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

$ref or err("Please provide a --ref reference genome in FASTA format");
-r $ref or err("Can not read reference '$ref'");
$ref = File::Spec->rel2abs($ref);
msg("Using reference genome: $ref");

$input or err("Please specify an dataset with --input <dataset.tab>");
-r $input or err("Can not read dataset file '$input'");
my $set = Nullarbor::IsolateSet->new();
$set->load($input);
msg("Loaded", $set->num, "isolates:", $set->ids);

my %scheme = ( map { $_=>1 } split ' ', qx(mlst --list) );
msg("Found", scalar(keys %scheme), "MLST schemes");
$mlst or err("Please provide an --mlst <scheme> from this list:\n", sort keys %scheme);
err("Invalid --mlst '$mlst'") if ! exists $scheme{$mlst}; 
msg("Using scheme: $mlst");

$outdir or err("Please provide an --outdir folder.");
if (-d $outdir) {
  if ($force) {
    msg("Re-using existing folder: $outdir");
    for my $file (<$outdir/*.tab>, <$outdir/*.aln>) {
      msg("Removing previous run file: $file");
      unlink $file;
    }
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

my $IDFILE = 'isolates.txt';
my $REF = 'ref.fa';
my $R1 = "R1.fq.gz";
my $R2 = "R2.fq.gz";
my $CTG = "contigs.fa";
my $zcat = 'gzip -f -c -d';

#...................................................................................................
# Makefile logic

my @PHONY = qw(folders yields abricate kraken prokka);

$make{'.PHONY'  } = { DEP => \@PHONY };
$make{'.DEFAULT'} = { DEP => 'all'   };

$make{'all'} = { 
  DEP => [ $IDFILE, 'folders', 'report/index.html' ],
};

$make{'report/index.html'} = {
  DEP => 'report/index.md',
  CMD => "pandoc --from markdown_github --to html --css 'nullarbor.css' $make_dep > $make_target"
};

$make{'report/index.md'} = {
  DEP => [ $REF, @PHONY, 'core.nogaps.aln', qw(mlst.tab denovo.tab tree.gif distances.tab) ],
  CMD => "$FindBin::RealBin/nullarbor.pl --name $name --report --indir $outdir --outdir $outdir/report",
};

if (my $dir = $cfg->{publish}) {
  $make{'publish'} = {
    DEP => 'report/index.html',
    CMD => [
      "mkdir -p \Q$dir/$name\E",
      "install -p -D -t \Q$dir/$name\E report/*",
    ],
  };
}
  
$make{$REF} = { 
  DEP => $ref, 
  CMD => "cp $make_dep $make_target",
};

# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# START per isolate
open ISOLATES, '>', "$outdir/$IDFILE";
for my $s ($set->isolates) {
  msg("Preparing rules for isolate:", $s->id);
  my $dir = File::Spec->rel2abs( File::Spec->catdir($outdir, $s->id) );
  $s->folder($dir);
  my $id = $s->id;
  my @reads = @{$s->reads};
  @reads != 2 and err("Sample '$id' only has 1 read, need 2 (paired).");
  my @clipped = ("$id/$R1", "$id/$R2");
  print ISOLATES "$id\n";

#  make_path($dir);
  $make{"$id"} = {
    CMD => [ "mkdir -p $make_target" ],
  };
  $make{"$id/yield.dirty.tab"} = {
    DEP => [ @reads ],
    CMD => "fq --quiet --ref $ref @reads > $make_target",
  };
  $make{"$id/yield.clean.tab"} = {
    DEP => [ @clipped ],
    CMD => "fq --quiet --ref $ref $make_deps > $make_target",
  };
  $make{$clipped[0]} = {
    DEP => [ @reads ],
    CMD => [ "skewer --quiet -t $cpus -n -q 10 -z -o $id/clipped @reads ".($cfg->{skewer} || ''),
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
      # v0.2.1 will not allow outputting to an existing folder
      "rm -f -r $id/megahit",
      # FIXME: make --min-count a function of sequencing depth
##      "megahit -m 16E9 -l 610 --out-dir $id/megahit --input-cmd '$zcat $make_deps' --cpu-only -t $cpus --k-min 31 --k-max 71 --k-step 20 --min-count 3",
##      "megahit -t $cpus -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --k-min 41 --k-max 101 --k-step 20 --min-count 3 --min-contig-len 500 --no-mercy",
      "megahit -t $cpus --memory 0.5 -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --presets bulk --min-contig-len 500",
      "mv $id/megahit/final.contigs.fa $make_target",
      "mv $id/megahit/log $id/megahit.log",
      "rm -f -v -r $id/megahit",
    ],
  };
  $make{"$id/kraken.tab"} = {
    DEP => [ @clipped ],
    CMD => "kraken --threads $cpus --preload --paired @clipped | kraken-report > $make_target",
  };
  $make{"$id/abricate.tab"} = {
    DEP => "$id/$CTG",
    CMD => "abricate $make_deps > $make_target",
  };
  $make{"$id/mlst.tab"} = {
    DEP => "$id/$CTG",
    CMD => "mlst --scheme $mlst $make_deps > $make_target",
  };
  $make{"$id/denovo.tab"} = {
    DEP => "$id/$CTG",
    CMD => "fa -e -t $make_deps > $make_target",
  };  
  $make{"$id/$id/snps.tab"} = {
    DEP => [ $REF, @clipped ],
    CMD => "snippy --cpus $cpus --force --outdir $id/$id --ref $REF --R1 $clipped[0] --R2 $clipped[1]",
  };
  $make{"$id/prokka/$id.gff"} = {
    DEP => "$id/$CTG",
    CMD => "prokka --force --fast --locustag $id --prefix $id --outdir $id/prokka --cpus $cpus $make_deps",
  };
}
close ISOLATES;
#END per isolate
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$make{"folders"} = { 
  DEP => [ $set->ids ],
};

$make{"yields"} = { 
  DEP => [ map { ("$_/yield.dirty.tab", "$_/yield.clean.tab") } $set->ids ],
};

$make{"abricate"} = { 
  DEP => [ map { "$_/abricate.tab" } $set->ids ],
};

$make{"kraken"} = { 
  DEP => [ map { "$_/kraken.tab" } $set->ids ],
};

$make{"prokka"} = { 
  DEP => [ map { "$_/prokka/$_.gff" } $set->ids ],
};

$make{"roary"} = { 
  DEP => "gene_presence_absence.csv",
};

$make{"gene_presence_absence.csv"} = { 
  DEP => [ map { "$_/prokka/$_.gff" } $set->ids ],
  CMD => "roary -v -p $cpus $make_deps",
};

$make{"mlst.tab"} = {
  DEP => [ map { "$_/mlst.tab" } $set->ids ],
  CMD => "(head -n 1 $make_dep && tail -q -n +2 $make_deps) > $make_target",
};
  
$make{"denovo.tab"} = {
  DEP => [ map { "$_/denovo.tab" } $set->ids ],
  CMD => "(head -n 1 $make_dep && tail -q -n +2 $make_deps) > $make_target",
};

$make{'core.aln'} = {
  DEP => [ $IDFILE, map { ("$_/$_/snps.tab") } $set->ids ],
  CMD => "snippy-core ".join(' ', map { "$_/$_" } $set->ids),
};

$make{'core.full.aln'} = {
  DEP => 'core.aln',
};

$make{'core.nogaps.aln'} = {
  DEP => 'core.full.aln',
  CMD => "trimal -in $make_deps -out $make_target -nogaps",
};

$make{'tree.newick'} = {
  DEP => 'core.aln',
  CMD => "env OMP_NUM_THREADS=$cpus OMP_THREAD_LIMIT=$cpus FastTree -gtr -nt $make_dep | nw_order -c n - > $make_target",
};

$make{'tree.svg'} = {
  DEP => 'tree.newick',
#  CMD => "figtree -graphic GIF -width 1024 -height 1024 $make_dep $make_target",
  CMD => "nw_display -S -s -w 1024 -l 'font-size:12' -i 'opacity:0' -b 'opacity:0' $make_dep > $make_target",
};

$make{'tree.gif'} = {
  DEP => 'tree.svg',
  CMD => "convert $make_dep $make_target",
};

$make{'distances.tab'} = {
  DEP => 'core.aln',
  CMD => "afa-pairwise.pl $make_dep > $make_target",
};

my $ptree = "parsnp/parsnp.tree";
$make{"parsnp"} = { DEP => $ptree };
$make{$ptree} = {
  DEP => [ $REF, map { "$_/$CTG" } $set->ids ],
  CMD => [ 
    "mkdir -p parsnp/genomes",
    (map { "ln -sf $outdir/$_/contigs.fa $outdir/parsnp/genomes/$_.fa" } $set->ids),
    "parsnp -p $cpus -c -d parsnp/genomes -r $ref -o parsnp",
  ],
};

#print Dumper(\%make);
my $makefile = "$outdir/Makefile";
open my $make_fh, '>', $makefile or err("Could not write $makefile");
write_makefile(\%make, $make_fh);
if ($run) {
  exec("nice make -C $outdir") or err("Could not run pipeline's Makefile");
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
  print $fh "MAKEFLAGS += --no-builtin-rules\n";
  print $fh "MAKEFLAGS += --no-builtin-variables\n";
  print $fh ".SUFFIXES:\n";

  for my $target ('all', sort grep { $_ ne 'all' } keys %$make) {
    print $fh "\n";
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
#  print "(1) Analyse samples\n";
  print "  $EXE [options] --name NAME --mlst SCHEME --ref REF.FA --input SAMPLES.TAB --outdir DIR\n";
  print "    --force     Overwrite --outdir (useful for adding samples to existing analysis)\n";
  print "    --cpus      Maximum number of CPUs to allow one command to use\n";
  print "    --quiet     No output\n";
  print "    --verbose   More output\n";
  print "    --version   Tool version\n";
  print "    --conf      Config file ($conf_file)\n";
#  print "(2) Generate report  ** NOTE: done automatically by (1) - see report/ folder **\n";
#  print "  $EXE [options] --indir DIR --outdir WEBDIR --name JOBNAME\n";
  print "    --version   Tool version\n";
  exit;
}

#-------------------------------------------------------------------
sub version {
  print "$EXE $VERSION\n";
  exit;
}
