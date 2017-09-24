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
use Cwd;

#-------------------------------------------------------------------
# local modules 

use FindBin;
use lib "$FindBin::RealBin/../perl5";
use Nullarbor::IsolateSet;
use Nullarbor::Logger qw(msg err);
use Nullarbor::Report;
use Nullarbor::Requirements qw(require_exe require_perlmod require_version require_var require_file);
use Nullarbor::Utils qw(num_cpus);
use Nullarbor::Plugins;

#-------------------------------------------------------------------
# constants

my $EXE = "$FindBin::RealScript";
my $VERSION = '1.30-dev';
my $AUTHOR = 'Torsten Seemann <torsten.seemann@gmail.com>';
my $URL = "https://github.com/tseemann/nullarbor";
my @CMDLINE = ($0, @ARGV);

#-------------------------------------------------------------------
# parameters

my $verbose = 0;
my $quiet   = 0;
my $ref = '';
my $mlst = '';
my $input = '';
my $outdir = '';
my $cpus = max( 2, num_cpus() );  # megahit needs 2
my $force = 0;
my $run = 0;
#my $report = 0;
my $indir = '';
my $name = '';
my $accurate = 0;
my $keepfiles = 0;
my $fullanno = 0;
my $trim = 0;
my $conf_file = "$FindBin::RealBin/../conf/nullarbor.conf";
my $check = 0;
my $gcode = 0; # prokka genetic code (0=auto)

#plugins
my $trimmer = '';
my $trimmer_opt = '';
my $assembler = 'shovill';
my $assembler_opt = '';
my $treebuilder = 'fasttree';
my $treebuilder_opt = '';
my $recomb = '';
my $recomb_opt = '';

@ARGV or usage();

GetOptions(
  "help"     => \&usage,
  "version"  => \&version, 
  "check"    => \$check, 
  "verbose"  => \$verbose,
  "quiet"    => \$quiet,
  "conf=s"   => \$conf_file,
  "mlst=s"   => \$mlst,
  "gcode=i"  => \$gcode,
  "ref=s"    => \$ref,
  "cpus=i"   => \$cpus,
  "input=s"  => \$input,
  "outdir=s" => \$outdir,
  "force!"   => \$force,
  "run!"     => \$run,
  "accurate!"=> \$accurate,
  "trim!"    => \$trim,
  "indir=s"  => \$indir,
  "name=s"   => \$name,
  "fullanno!"         => \$fullanno,
  "keepfiles!"        => \$keepfiles,
  # plugins
  "trimmer=s"         => \$trimmer,
  "trimmer-opt=s"     => \$trimmer_opt,
  "assembler=s"       => \$assembler,
  "assembler-opt=s"   => \$assembler_opt,
  "treebuilder=s"     => \$treebuilder,
  "treebuilder-opt=s" => \$treebuilder_opt,
  "recomb=s"          => \$recomb,
  "recomb-opt=s"      => \$recomb_opt,
) 
or usage();

Nullarbor::Logger->quiet($quiet);

msg("Hello", $ENV{USER} || 'stranger');
msg("This is $EXE $VERSION");
msg("Send complaints to $AUTHOR");

if ($check) {
  check_deps();
  exit(0);
}

#if ($report) {
#  msg("Running in --report mode");
#  $indir or err("Please set the --indir folder to a $EXE output folder");
#  $outdir or err("Please set the --outdir output folder.");
#  $name or err("Please specify a report --name");
#  make_path($outdir) unless -f $outdir;
#  Nullarbor::Report->generate($indir, $outdir, $name);
#  exit;
#}

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
$set->num >= 4 or err("$EXE requires a mininum of 4 isolates to run (due to Roary)");
$input = File::Spec->rel2abs($input);

if ($mlst) {
  require_exe('mlst');
  my %scheme = ( map { $_=>1 } split ' ', qx(mlst --list) );
  msg("Found", scalar(keys %scheme), "MLST schemes");
  err("Invalid --mlst '$mlst' - type 'mlst --list` to see available schemes.") if ! exists $scheme{$mlst}; 
  msg("Using scheme: $mlst");
}
else {
  msg("Will auto-detect the MLST scheme");
}

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

# check dependencies and return here if all goes well
check_deps(); 

# load config file 
my $cfg;
if (-r $conf_file) {
  my $yaml = YAML::Tiny->read( $conf_file );
  $cfg = $yaml->[0];
#  print Dumper($cfg);
  msg("Loaded YAML config: $conf_file");
#  msg("Options set:", keys %$cfg);
  for my $opt (keys %$cfg) {
    $cfg->{$opt} =~ s/\$HOME/$ENV{HOME}/g;
    $cfg->{$opt} =~ s{\$NULLARBOR}{$FindBin::RealBin/..}g;
    msg("- $opt = $cfg->{$opt}");
  }
}
else {
  msg("Could not read config file: $conf_file");
}

my $plugin = Nullarbor::Plugins->discover();
msg(Dumper($plugin));

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
my $CPUS = '$(CPUS)';
my $NW_DISPLAY = "nw_display ".($cfg->{nw_display} || '');
my $SNIPPY = '$(SNIPPY)';
my $DELETE = "rm -f";

my $TEMPDIR = $cfg->{tempdir} || $ENV{TMPDIR} || '/tmp';
msg("Will use temp folder: $TEMPDIR");
my $JOBRAM = $cfg->{jobram} || undef;

$make{'.DEFAULT'} = { DEP => 'all' };

$make{'all'} = { 
  DEP => [ 'folders', 'report' ],
};

my @CMDLINE_NO_FORCE = grep !m/^--?f\S*$/, @CMDLINE; # remove --force / -f etc
$make{'again'} = {
  CMD => "(rm -fr roary/ core.* *.tab tree.* && cd .. && @CMDLINE_NO_FORCE --force)",
};

$make{'report'} = {
  DEP => [ 'report/index.html' ],
};
$make{'report'}{'CMD'} = "make space" unless $keepfiles;

$make{'report/index.html'} = {
  DEP => [ $REF, qw(yields kraken abricate virulome mlst.tab denovo.tab core.aln tree.gif distances.tab roary) ],
  CMD => "$FindBin::RealBin/nullarbor-report.pl --name $name --indir $outdir --outdir $outdir/report",
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
#    "any2fasta.pl $make_dep > $make_target",
    "seqret -auto -filter -osformat2 fasta < $make_dep > $make_target",
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

  # Solve a lot of issues by just making the paths here instead of the makefile!
  make_path($dir);

  $make{"$id"} = {
#    CMD => [ "if [ ! -d '$make_target' ]; then mkdir -p $make_target ; fi" ],
    CMD => [ "mkdir -p $make_target" ],
  };
  $make{"$id/yield.dirty.tab"} = {
    DEP => [ @reads, $REF ],
    CMD => "fq --quiet --ref $REF @reads > $make_target",
  };
  $make{"$id/yield.clean.tab"} = {
    DEP => [ @clipped ],
    CMD => "fq --quiet --ref $REF $make_deps > $make_target",
  };
  $make{$clipped[0]} = {
    DEP => [ @reads ],
    CMD => $trim ? [ "trimmomatic PE -threads $CPUS -phred33 @reads $id/$R1 /dev/null $id/$R2 /dev/null ".($cfg->{trimmomatic} || '') ]
                 : [ "ln -f -s '$reads[0]' '$id/$R1'", "ln -f -s '$reads[1]' '$id/$R2'" ],
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
#        "spades.py -t $CPUS -1 $clipped[0] -2 $clipped[1] -o $id/spades --only-assembler --careful",
        "spades.py --tmp-dir '$TEMPDIR' -t $CPUS -1 $clipped[0] -2 $clipped[1] -o $id/spades --only-assembler --careful",
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
        "mkdir -p $id",
        "megahit --min-count 3 --k-list 21,31,41,53,75,97,111,127 -t $CPUS --memory 0.5 -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --min-contig-len 500",
#        "megahit -t $CPUS --memory 0.5 -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --presets bulk --min-contig-len 500",
#        "megahit -t $CPUS --memory 0.5 -1 $clipped[0] -2 $clipped[1] --out-dir $id/megahit --presets bulk",
        "mv $id/megahit/final.contigs.fa $make_target",
        "mv $id/megahit/log $id/megahit.log",
        "rm -f -v -r $id/megahit",
      ],
    };
  }
  $make{"$id/kraken.tab"} = {
    DEP => [ @clipped ],
    CMD => "kraken --threads $CPUS --preload --paired @clipped | kraken-report > $make_target",
  };
  $make{"$id/abricate.tab"} = {
    DEP => "$id/$CTG",
    CMD => "abricate $make_deps > $make_target",
  };
  $make{"$id/virulome.tab"} = {
    DEP => "$id/$CTG",
    CMD => "abricate --db vfdb $make_deps > $make_target",
  };
  $make{"$id/mlst.tab"} = {
    DEP => "$id/$CTG",
    CMD => "mlst ".($mlst ? "--scheme $mlst" : "")." $make_deps > $make_target",
  };
  $make{"$id/denovo.tab"} = {
    DEP => "$id/$CTG",
    CMD => "fa -e -t $make_deps > $make_target",
  };  
  $make{"$id/$id/snps.tab"} = {
    DEP => [ $ref, @clipped ],
    CMD => "$SNIPPY --cpus $CPUS --force --outdir $id/$id --ref $ref --R1 $clipped[0] --R2 $clipped[1]",
  };
  my $prokka_opt = "--centre X --compliant --force";
  $prokka_opt .= " --fast" unless $fullanno;
  $make{"$id/prokka/$id.gff"} = {
    DEP => "$id/$CTG",
    CMD => "prokka $prokka_opt --gcode $gcode --locustag $id --prefix $id --outdir $id/prokka --cpus $CPUS $make_deps",
  };
  $make{"$id/$id.msh"} = { 
    DEP => [ @clipped ],
    CMD => "mash sketch -o $id/$id $make_deps",
  };
  $make{"$id/cortex.fa"} = { 
#    DEP => [ @clipped ],
    DEP => [ @reads ],
    CMD => [
#      "mccortex31 build -m 4G -t $CPUS -s $id -k 31 -2 $clipped[0]:$clipped[1] $id/raw.ctx",
      "mccortex31 build -m 4G -t $CPUS -s $id -k 31 -2 $reads[0]:$reads[1] $id/raw.ctx",
      "mccortex31 clean -m 4G -t $CPUS -o $id/clean.ctx $id/raw.ctx",
      "mccortex31 unitigs -m 4G -t $CPUS $id/clean.ctx > $make_target",
      "$DELETE $id/{clean,raw}.ctx",
    ],
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

$make{"virulome"} = { 
  DEP => [ map { "$_/virulome.tab" } $set->ids ],
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

$make{"cortex"} = { 
  DEP => [ map { "$_/cortex.fa" } $set->ids ],
};

$make{"clip"} = { 
  DEP => [ map { "$_/yield.clean.tab" } $set->ids ],
};

$make{"roary"} = { 
  DEP => [ "roary/roary.png", "roary/accessory_tree.png" ],   
};

$make{'roary/accessory_binary_genes.fa.newick'} = {
  DEP => 'roary/gene_presence_absence.csv',
};

$make{'roary/accessory_tree.png'} = {
  DEP => 'roary/accessory_binary_genes.fa.newick',
  CMD => [
    "nw_order -c n $make_dep | $NW_DISPLAY - > $make_dep.svg",
    "convert $make_dep.svg $make_target",
  ],
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
    "roary -f roary -v -p $CPUS $make_deps",
  ],
};

$make{"mlst.tab"} = {
  DEP => [ map { "$_/mlst.tab" } $set->ids ],
  CMD => "cat $make_deps > $make_target",
};
  
$make{"denovo"} = {
  DEP => "denovo.tab",
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

$make{'tree.newick'} = {
  DEP => 'core.aln',
  CMD => "env OMP_NUM_THREADS=$CPUS OMP_THREAD_LIMIT=$CPUS FastTree -gtr -nt $make_dep | nw_order -c n - > $make_target",
};

$make{'tree.svg'} = {
  DEP => 'tree.newick',
  CMD => "$NW_DISPLAY $make_dep > $make_target",
};

$make{'tree.gif'} = {
  DEP => 'tree.svg',
  CMD => "convert $make_dep $make_target",
};

$make{'distances.tab'} = {
  DEP => 'core.aln',
  CMD => "snp-dists -b $make_dep > $make_target",
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

$make{'space'} = {
  CMD => [
    # overall
    "$DELETE core.full.aln core.vcf",
    # roary
    "$DELETE roary/*.{tab,embl,dot,Rtab}",
    # isolate :: denovo et al
    (map { "$DELETE $_/*.ctx $_/megahit.log" } $set->ids),
    # isolate :: prokka
    (map { "$DELETE $_/prokka/*.{err,ffn,fsa,sqn,tbl,tsv}" } $set->ids),
    # isolate :: snippy
    (map { "$DELETE $_/$_/*consensus*fa $_/$_/*.{gz,tbi,vcf,vcf.gz,bed,bam,bai,html,csv,gff,txt,log}" } $set->ids),
    # isolate :: snipppy :: reference (recursive)
    (map { "$DELETE -r $_/$_/reference/" } $set->ids),
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

  # copy any header stuff from the __DATA__ block at the end of this script
  while (<DATA>) {
    print $fh $_;
  }
  
  print $fh "# Command line:\n# cd ".getcwd()."\n# @CMDLINE\n\n";

  print $fh "SHELL := /bin/bash\n";
  print $fh "MAKEFLAGS += --no-builtin-rules\n";
  print $fh "MAKEFLAGS += --no-builtin-variables\n";
  print $fh "CPUS=$threads\n";
  print $fh "SNIPPY=snippy\n";
  print $fh ".SUFFIXES:\n";
#  print $fh ".SUFFIXES: .newick .tree .aln .png .svg\n";
  print $fh ".DELETE_ON_ERROR:\n\n";
  
  print $fh "%.png : %.svg\n",
            "\tconvert $make_dep $make_target\n";
  print $fh "%.svg : %.newick\n",
            "\t$NW_DISPLAY $make_dep > $make_target\n"; 
  print $fh "%.newick : %.aln\n",
            "\tenv OMP_NUM_THREADS=$CPUS OMP_THREAD_LIMIT=$CPUS FastTree -gtr -nt $< | nw_order -c n - > $@";

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
  my($ok) = @_;
  select STDERR if not $ok;

  print "NAME\n  $EXE $VERSION\n";
  print "SYNOPSIS\n  Reads to reports for public health microbiology\n";
  print "AUTHOR\n  $AUTHOR\n";
  print "USAGE\n";
  print "  $EXE [options] --name NAME --ref REF.FA/GBK --input INPUT.TAB --outdir DIR\n";
  print "REQUIRED\n";
  print "    --name STR               Job name\n";
  print "    --ref FILE               Reference file in FASTA or GBK format\n";
  print "    --input FILE             Input TSV file with format:  | Isolate_ID | R1.fq.gz | R2.fq.gz |\n";
  print "    --outdir DIR             Output folder\n";
  print "OPTIONS\n";
  print "    --cpus INT               Maximum number of CPUs to use in total ($cpus)\n";
  print "    --force                  Overwrite --outdir (useful for adding samples to existing analysis)\n";
  print "    --quiet                  No screen output\n";
  print "    --verbose                More screen output\n";
  print "    --version                Print version and exit\n";
  print "    --check                  Check dependencies and exit\n";
  print "    --run                    Immediately launch Makefile\n";
  print "ADVANCED OPTIONS\n";
  print "    --conf FILE              Config file ($conf_file)\n";
  print "    --gcode INT              Genetic code for prokka ($gcode)\n";
  print "    --trim                   Trim reads of adaptors ($trim)\n";
  print "    --mlst SCHEME            Force this MLST scheme (AUTO)\n";
  print "    --accurate               Run as slow as possible for the hope of improved accuracy\n";
  print "    --fullanno               Don't use --fast for Prokka\n";
  print "    --keepfiles              Keep ALL ancillary files to annoy your sysadmin\n";
  print "PLUGINS (CURRENTLY NOT WORKING)\n";
#  print "    --trimmer NAME           Read trimmer to use ($trimmer)\n";
#  print "    --trimmer-opt STR        Read trimmer options to pass ($trimmer_opt)\n";
  print "    --assembler NAME         Assembler to use ($assembler)\n";
  print "    --assembler-opt STR      Extra assembler options to pass ($assembler_opt)\n";
  print "    --treebuilder NAME       Tree-builder to use ($treebuilder)\n";
  print "    --treebuilder-opt STR    Extra tree-builder options to pass ($treebuilder_opt)\n";
#  print "    --recomb NAME            Recombination masker ($recomb)\n";
#  print "    --recomb-opt STR         Extra recombination marker options to pass ($recomb_opt)\n";
  print "DOCUMENTATION\n";
  print "    $URL\n";
  
  exit( $ok ? 0 : 1);
}

#-------------------------------------------------------------------
sub version {
  print "$EXE $VERSION\n";
  exit;
}

#-------------------------------------------------------------------
sub check_deps { 
  my($self) = @_;

  require_exe( qw'convert head cat install env nl' );
  require_exe( qw'trimmomatic prokka roary kraken snippy mlst abricate megahit spades.py shovill nw_order nw_display FastTree snp-dists seqret' );
  require_exe( qw'fq fa roary2svg.pl' );

  require_perlmod( qw'Data::Dumper Moo Bio::SeqIO File::Copy Time::Piece YAML::Tiny File::Slurp File::Copy SVG Text::CSV List::MoreUtils' );

  require_version('shovill', 0.8);
  require_version('megahit', 1.1);
  require_version('snippy', 3.1);
  require_version('prokka', 1.12);
  require_version('roary', 3.9, undef, '-w'); # uses -w
  require_version('mlst', 2.10);
  require_version('snp-dists', 0.2, undef, '-v'); # supports -v not --version
  require_version('trimmomatic', 0.36, undef, '-version'); # supports -v not --version
  #require_version('spades.py', 3.5); # does not have a --version flag

  my $value = require_var('KRAKEN_DEFAULT_DB', 'kraken');
  require_file("$value/database.idx", 'kraken');
  require_file("$value/database.kdb", 'kraken');

  msg("All $EXE $VERSION dependencies seem to be installed correctly :-)")
}

#-------------------------------------------------------------------

__DATA__
# This file was automatically generated by the Nullarbor software

