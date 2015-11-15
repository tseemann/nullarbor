#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Spec qw(catfile);
use List::Util qw(min max);
use YAML::Tiny;

#-------------------------------------------------------------------
# local modules 

use FindBin;
use lib "$FindBin::RealBin/../perl5";
use Nullarbor::IsolateSet;
use Nullarbor::Logger qw(msg err);
use Nullarbor::Report;
use Nullarbor::Requirements qw(require_exe require_perlmod require_version require_var require_file);
use Nullarbor::Utils qw(num_cpus);

#-------------------------------------------------------------------
# constants

my $EXE = "$FindBin::RealScript";
my $VERSION = '0.8-dev';
my $AUTHOR = 'Torsten Seemann <torsten.seemann@gmail.com>';
my @CMDLINE = ($0, @ARGV);

#-------------------------------------------------------------------
# parameters

my $verbose = 0;
my $quiet   = 0;
my $ref = '';
my $mlst = '';
my $input = '';
my $outdir = '';
my $cpus = num_cpus();
my $force = 0;
my $run = 0;
my $report = 0;
my $indir = '';
my $name = '';
my $accurate = 0;
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
  "accurate!"=> \$accurate,
  "indir=s"  => \$indir,
  "name=s"   => \$name,
) 
or usage();

Nullarbor::Logger->quiet($quiet);

msg("Hello", $ENV{USER} || 'stranger');
msg("This is $EXE $VERSION");
msg("Send complaints to $AUTHOR");

if ($report) {
  msg("Running in --report mode");
  $indir or err("Please set the --indir folder to a $EXE output folder");
  $outdir or err("Please set the --outdir output folder.");
  $name or err("Please specify a report --name");
  make_path($outdir) unless -f $outdir;
  Nullarbor::Report->generate($indir, $outdir, $name);
  exit;
}

$name or err("Please provide a --name for the project.");
$name =~ m{/|\s} and err("The --name is not allowed to have spaces or slashes in it.");

$ref or err("Please provide a --ref reference genome");
-r $ref or err("Can not read reference '$ref'");
$ref = File::Spec->rel2abs($ref);
msg("Using reference genome: $ref");

$input or err("Please specify an dataset with --input <dataset.tab>");
-r $input or err("Can not read dataset file '$input'");
my $set = Nullarbor::IsolateSet->new();
$set->load($input);
msg("Loaded", $set->num, "isolates:", $set->ids);

if (not $mlst) {
  require_exe( qw'any2fasta.pl bash mash sort head' );
  msg("No --mlst specified, attempting to auto-detect using $ref ...");
  my($line) = qx{bash -c "mash dist '$FindBin::RealBin/../db/mlst.msh' <(any2fasta.pl '$ref') | sort -k3g | head -n 1"};
  chomp $line;
  my @col = split m/\t/, $line;
  $mlst = $col[0] || '';
  msg( $mlst ? "Chose MLST scheme: $mlst" : "Could not auto-detect MLST scheme" );
}

$mlst or err("Please provide an MLST scheme");
require_exe('mlst');
my %scheme = ( map { $_=>1 } split ' ', qx(mlst --list) );
$mlst or err("Invalid --mlst scheme. Please choose from:\n", sort keys %scheme);
msg("Found", scalar(keys %scheme), "MLST schemes");
err("Invalid --mlst '$mlst'") if ! exists $scheme{$mlst}; 
msg("Using scheme: $mlst");

$outdir or err("Please provide an --outdir folder.");
if (-d $outdir) {
  if ($force) {
    msg("Re-using existing folder: $outdir");
#    for my $file (<$outdir/*.tab>, <$outdir/*.aln>) {
#      msg("Removing previous run file: $file");
#      unlink $file;
#    }
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

require_exe( qw'convert pandoc head cat install env nl date' );
require_exe( qw'mash prokka roary kraken snippy mlst abricate megahit spades.py nw_order nw_display FastTree' );
require_exe( qw'fq fa afa-pairwise.pl any2fasta.pl roary2svg.pl' );

require_perlmod( qw'Data::Dumper Moo Bio::SeqIO File::Copy Time::Piece YAML::Tiny' );

require_version('megahit', 1.0);
require_version('snippy', 2.5);
require_version('prokka', 1.10);
require_version('roary', 3.4);
#require_version('spades.py', 3.5); # does not have a --version flag

my $value = require_var('KRAKEN_DEFAULT_DB', 'kraken');
require_file("$value/database.idx", 'kraken');
require_file("$value/database.kdb", 'kraken');

my $cfg;
if (-r $conf_file) {
  my $yaml = YAML::Tiny->read( $conf_file );
  $cfg = $yaml->[0];
#  print Dumper($cfg);
  msg("Loaded YAML config: $conf_file");
#  msg("Options set:", keys %$cfg);
  for my $opt (keys %$cfg) {
    $cfg->{$opt} =~ s/\$HOME/$ENV{HOME}/g;
    msg("- $opt = $cfg->{$opt}");
  }
}
else {
  msg("Could not read config file: $conf_file");
}

my $nsamp = $set->num or err("Data set appears to have no isolates?");
msg("Optimizing use of $cpus cores for $nsamp isolates.");
my $threads = max( min(4, $cpus), int($cpus/$nsamp) );  # try and use 4 cpus per job if possible
my $jobs = min( $nsamp, int($cpus/$threads) );
msg("Will run concurrent $jobs jobs with $threads threads each.");

#...................................................................................................
# Makefile logic

my %make;
my $make_target = '$@';
my $make_dep = '$<';
my $make_deps = '$^';

my $IDFILE = 'isolates.txt';
my $REF = 'ref.fa';
my $R1 = "R1.fq.gz";
my $R2 = "R2.fq.gz";
my $CTG = "contigs.fa";
my $zcat = 'gzip -f -c -d';

$make{'.DEFAULT'} = { DEP => 'all'   };

$make{'all'} = { 
  DEP => [ 'folders', 'report' ],
};

my @CMDLINE_NO_FORCE = grep !m/^--?f\S*$/, @CMDLINE; # remove --force / -f etc
$make{'again'} = {
  CMD => "(cd .. && @CMDLINE_NO_FORCE --force)",
};

$make{'report'} = {
  DEP => 'report/index.html',
};

$make{'report/index.html'} = {
  DEP => 'report/index.md',
  CMD => "pandoc --standalone --toc --from markdown_github+pandoc_title_block --to html --css 'nullarbor.css' $make_dep > $make_target"
};

$make{'report/index.md'} = {
  DEP => [ $REF, qw(yields kraken abricate mlst.tab mlst2.tab denovo.tab core.aln tree.gif distances.tab roary/roary.png) ],
  CMD => "$FindBin::RealBin/nullarbor.pl --name $name --report --indir $outdir --outdir $outdir/report",
};

if (my $dir = $cfg->{publish}) {
  $make{'publish'} = {
    DEP => 'report/index.html',
    CMD => [
      "mkdir -p \Q$dir/$name\E",
      "install -p -D -t \Q$dir/$name\E report/*",
    ],
    PHONY => 1,
  };
}
  
$make{$REF} = { 
  DEP => $ref, 
  CMD => [
    "any2fasta.pl $make_dep > $make_target",
    "samtools faidx $make_target",
  ],
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
    CMD => "fq --quiet --ref $REF @reads > $make_target",
  };
  $make{"$id/yield.clean.tab"} = {
    DEP => [ @clipped ],
    CMD => "fq --quiet --ref $REF $make_deps > $make_target",
  };
  $make{$clipped[0]} = {
    DEP => [ @reads ],
    CMD => [ "skewer --quiet -t $threads -n -q 10 -z -o $id/clipped @reads ".($cfg->{skewer} || ''),
             "mv $id/clipped-trimmed-pair1.fastq.gz $id/$R1",
             "mv $id/clipped-trimmed-pair2.fastq.gz $id/$R2", ],
  };
  # we need this special rule to handle the 'double dependency' problem
  # http://www.gnu.org/software/automake/manual/html_node/Multiple-Outputs.html#Multiple-Outputs
  $make{$clipped[1]} = { 
    DEP => [ $clipped[0] ],
  };
  
  if ($accurate) {
    $make{"$id/$CTG"} = {
      DEP => [ @clipped ],
      CMD => [ 
        "rm -f -r $id/spades",
        "spades.py -t $threads -1 $clipped[0] -2 $clipped[1] -o $id/spades --only-assembler --careful --cov-cutoff auto",
        "mv $id/spades/scaffolds.fasta $make_target",
        "mv $id/spades/spades.log $id/spades.log",
        "rm -f -v -r $id/spades",
      ],
    };
  }
  else {
    $make{"$id/$CTG"} = {
      DEP => [ @clipped ],
      CMD => [ 
        "rm -f -r $id/megahit",
#        "megahit -t $threads --memory 0.5 -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --presets bulk --min-contig-len 500",
        "megahit -t $threads --memory 0.5 -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --presets bulk",
        "mv $id/megahit/final.contigs.fa $make_target",
        "mv $id/megahit/log $id/megahit.log",
        "rm -f -v -r $id/megahit",
      ],
    };
  }
  $make{"$id/kraken.tab"} = {
    DEP => [ @clipped ],
    CMD => "kraken --threads $threads --preload --paired @clipped | kraken-report > $make_target",
  };
  $make{"$id/abricate.tab"} = {
    DEP => "$id/$CTG",
    CMD => "abricate $make_deps > $make_target",
  };
  $make{"$id/mlst.tab"} = {
    DEP => "$id/$CTG",
    CMD => "mlst --scheme $mlst $make_deps > $make_target",
  };
  $make{"$id/mlst2.tab"} = {
    DEP => "$id/$CTG",
    CMD => "mlst2 $make_deps > $make_target",
  };
  $make{"$id/denovo.tab"} = {
    DEP => "$id/$CTG",
    CMD => "fa -e -t $make_deps > $make_target",
  };  
  $make{"$id/$id/snps.tab"} = {
    DEP => [ $ref, @clipped ],
    CMD => "snippy --cpus $threads --force --outdir $id/$id --ref $ref --R1 $clipped[0] --R2 $clipped[1]",
  };
  $make{"$id/prokka/$id.gff"} = {
    DEP => "$id/$CTG",
    CMD => "prokka --centre X --compliant --force --fast --locustag $id --prefix $id --outdir $id/prokka --cpus $threads $make_deps",
  };
  $make{"$id/$id.msh"} = { 
    DEP => [ @clipped ],
    CMD => "mash sketch -o $id/$id $make_deps",
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

$make{"mash"} = { 
  DEP => [ map { "$_/$_.msh" } $set->ids ],
};

$make{"roary"} = { 
  DEP => "roary/roary.png",
};

$make{"roary/roary.png"} = { 
  DEP => "roary/gene_presence_absence.csv",
  CMD => [
    "roary2svg.pl $make_dep > $make_target.svg",
    "convert $make_target.svg $make_target",
  ],
};

$make{"roary/gene_presence_absence.csv"} = { 
  DEP => [ map { "$_/prokka/$_.gff" } $set->ids ],
  CMD => [
    "rm -fr roary",
    "roary -f roary -v -p $threads $make_deps",
  ],
};

$make{"mlst.tab"} = {
  DEP => [ map { "$_/mlst.tab" } $set->ids ],
  CMD => "(head -n 1 $make_dep && tail -q -n +2 $make_deps) > $make_target",
};

$make{"mlst2.tab"} = {
  DEP => [ map { "$_/mlst2.tab" } $set->ids ],
  CMD => "cat $make_deps > $make_target",
};
  
$make{"denovo.tab"} = {
  DEP => [ map { "$_/denovo.tab" } $set->ids ],
  CMD => "(head -n 1 $make_dep && tail -q -n +2 $make_deps) > $make_target",
};

$make{'core.aln'} = {
  DEP => [ map { ("$_/$_/snps.tab") } $set->ids ],
  CMD => "snippy-core ".join(' ', map { "$_/$_" } $set->ids),
};

#$make{'core.full.aln'} = {
#  DEP => 'core.aln',
#};

#$make{'core.nogaps.aln'} = {
#  DEP => 'core.full.aln',
#  CMD => "trimal -in $make_dep -out $make_target -nogaps",
#};

$make{'tree.newick'} = {
  DEP => 'core.aln',
  CMD => "env OMP_NUM_THREADS=$threads OMP_THREAD_LIMIT=$threads FastTree -gtr -nt $make_dep | nw_order -c n - > $make_target",
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
$make{"parsnp"} = { 
  DEP => $ptree,
};

$make{$ptree} = {
  DEP => [ $REF, map { "$_/$CTG" } $set->ids ],
  CMD => [ 
    "mkdir -p parsnp/genomes",
    (map { "ln -sf $outdir/$_/contigs.fa $outdir/parsnp/genomes/$_.fa" } $set->ids),
    "parsnp -p $threads -c -d parsnp/genomes -r $REF -o parsnp",
  ],
};

my $help_file = "$FindBin::RealBin/../conf/make_help.txt";
$make{"help"} = {
  DEP => $help_file,
  CMD => "\@cat $make_dep",
};

$make{"list"} = {
  DEP => $IDFILE,
  CMD => "\@nl $make_dep",
};

my $panic_file = "$FindBin::RealBin/../conf/motd.txt";
$make{'panic'} = {
  DEP => $panic_file,
  CMD => "\@cat $make_dep",
};

my $DELETE = "rm -v -f";
$make{'space'} = {
  CMD => [
#    "$DELETE core.full.aln core.nogaps.aln\n",
    "$DELETE core.full.aln core.vcf\n",
    "$DELETE roary/*.{tab,embl,dot,Rtab}\n",
    (map { "$DELETE $_/prokka/*.{err,ffn,fsa,sqn,tbl} $_/$_/*consensus*fa $_/$_/*.{vcf,vcf.gz,vcf.tbi,bed,bam,bai,html}\n" } $set->ids),
  ],
};

#.............................................................................

#print Dumper(\%make);
my $makefile = "$outdir/Makefile";
open my $make_fh, '>', $makefile or err("Could not write $makefile");
write_makefile(\%make, $make_fh);
if ($run) {
  exec("nice make -j $jobs -C $outdir") or err("Could not run pipeline's Makefile");
}
else {
  #msg("Run the pipeline with: nohup nice make -C $outdir 1> $outdir/log.out $outdir/log.err");
  msg("Run the pipeline with: nice make -j $jobs -C $outdir");
}
msg("Done");

#----------------------------------------------------------------------
sub write_makefile {
  my($make, $fh) = @_;
  $fh = \*STDOUT if not defined $fh;
  
  print $fh "SHELL := /bin/bash\n";
  print $fh "MAKEFLAGS += --no-builtin-rules\n";
  print $fh "MAKEFLAGS += --no-builtin-variables\n";
#  print $fh "MAKEFLAGS += --load-average=$threads\n";
  print $fh ".SUFFIXES:\n";

  for my $target ('all', sort grep { $_ ne 'all' } keys %$make) {
    print $fh "\n";
    my $rule = $make->{$target}; # short-hand
    my $dep = $rule->{DEP};
    $dep = ref($dep) eq 'ARRAY' ? (join ' ', @$dep) : $dep;
    $dep ||= '';
    print $fh ".PHONY: $target\n" if $rule->{PHONY} or ! $rule->{DEP};
    print $fh "$target: $dep\n";
    if (my $cmd = $rule->{CMD}) {
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
  print "    --accurate  Invest more effort in the de novo assembly\n";
  print "    --force     Overwrite --outdir (useful for adding samples to existing analysis)\n";
  print "    --cpus      Maximum number of CPUs to use in total ($cpus)\n";
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
