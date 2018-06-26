#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path);
use List::Util qw(min max);
use YAML::Tiny;
use Cwd qw(realpath getcwd);
use Path::Tiny;
use Term::ANSIColor;

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
my $VERSION = '2.0.0-dev';
my $AUTHOR = 'Torsten Seemann';
my $URL = "https://github.com/tseemann/nullarbor";
my @CMDLINE = ($0, @ARGV);
my $APPDIR = realpath("$FindBin::RealBin/../conf");
my $LOGFILE = "nullarbor.log";

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
my $name = '';
my $keepfiles = 0;
my $fullanno = 0;
my $trim = 0;
my $conf_file = "$FindBin::RealBin/../conf/nullarbor.conf";
my $prefill = 0;
my $check = 0;
my $gcode = 11; # genetic code for prokka + roary

my $assembler = 'skesa';
my $assembler_opt = '';
my $treebuilder = 'iqtree';
my $treebuilder_opt = '';
my $taxoner = 'centrifuge';
my $taxoner_opt = '';
my $mask = '';

my $plugin = Nullarbor::Plugins->discover();
#msg(Dumper($plugin));

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
  "prefill!" => \$prefill,
  "mask=s"   => \$mask,
  "run!"     => \$run,
  "trim!"    => \$trim,
  "name=s"   => \$name,
  "fullanno!"         => \$fullanno,
  "keepfiles!"        => \$keepfiles,
  "assembler=s"       => \$assembler,
  "assembler-opt=s"   => \$assembler_opt,
  "treebuilder=s"     => \$treebuilder,
  "treebuilder-opt=s" => \$treebuilder_opt,
  "taxoner=s"     => \$taxoner,
  "taxoner-opt=s" => \$taxoner_opt,
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

$name or err("Please provide a --name for the project.");
$name =~ m{/|\s} and err("The --name is not allowed to have spaces or slashes in it.");

$ref or err("Please provide a --ref reference genome");
-r $ref or err("Can not read reference '$ref'");
$ref = realpath($ref);
msg("Using reference genome: $ref");

$input or err("Please specify an dataset with --input <dataset.tab>");
-r $input or err("Can not read dataset file '$input'");
my $set = Nullarbor::IsolateSet->new();
$set->load($input);
msg("Loaded", $set->num, "isolates:", $set->ids);
$set->num >= 4 or err("$EXE requires a mininum of 4 isolates to run (due to Roary)");
$input = realpath($input);

if ($mask and $mask ne 'auto') {
  -r $mask or err("Can not read --mask file '$mask'");
  $mask = realpath($mask);
  msg("Using mask: $mask");
}

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
  }
  else {
    err("The --outdir '$outdir' already exists. Try using --force");
  }
}
$outdir = realpath($outdir);
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
    $cfg->{$opt} =~ s/{HOME}/$ENV{HOME}/g;
    $cfg->{$opt} =~ s/{NULLARBOR}/$APPDIR/g;
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

my $IDFILE = 'isolates.txt';
my $R1 = "R1.fq.gz";
my $R2 = "R2.fq.gz";

my @CMDLINE_NO_FORCE = grep !m/^--?f\S*$/, @CMDLINE; # remove --force / -f etc
$make{'again'} = {
  CMD => "(rm -fr roary/ report/ core.* *.gff {denovo,mlst}.tab tree.* && cd .. && @CMDLINE_NO_FORCE --force)",
};

# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# START per isolate
open ISOLATES, '>', "$outdir/$IDFILE";
msg("Preparing isolate rules and creating $IDFILE");
for my $s ($set->isolates) {
  msg("Preparing rules for isolate:", $s->id) if $verbose;
  my $dir = realpath("$outdir/".$s->id);
  $s->folder($dir);
  my $id = $s->id;
  my @reads = @{$s->reads};
  @reads != 2 and err("Sample '$id' only has 1 read, need 2 (paired).");
  my @clipped = ("$id/$R1", "$id/$R2");
  print ISOLATES "$id\n";

  # Solve a lot of issues by just making the paths here instead of the makefile!
  make_path($dir);

  $make{$clipped[0]} = {
    DEP => [ @reads ],  # FIXME: should this be '|' ?
    CMD => $trim ? [ "trimmomatic PE -threads \$(CPUS) -phred33 @reads $id/$R1 /dev/null $id/$R2 /dev/null ".($cfg->{trimmomatic} || '') ]
                 : [ "ln -f -s '$reads[0]' '$id/$R1'", "ln -f -s '$reads[1]' '$id/$R2'" ],
  };
  
  # we need this special rule to handle the 'double dependency' problem
  # http://www.gnu.org/software/automake/manual/html_node/Multiple-Outputs.html#Multiple-Outputs
  $make{$clipped[1]} = { 
    DEP => [ $clipped[0] ],
  };
  
}
close ISOLATES;
#END per isolate

#.............................................................................

if ($prefill) {
  msg("Pre-filling $outdir");
  my $src = $cfg->{prefill};
  #msg(Dumper($src));
  for my $file (sort keys %$src) {
    my $copied=0;
    msg("Pre-filling '$file' from", $src->{$file});
    for my $s ($set->isolates) {
      my $id = $s->id;
      my $path = $src->{$file};
      $path =~ s/{ID}/$id/g or err("Could not find {ID} placeholder in '$path'");
      next unless -r $path;
      my $dest = "$outdir/$id/$file";
      my $opts = $verbose ? "-v" : "";
      my $cmd = "install $opts -p -T '$path' '$dest'"; # -p preserve timestamp
      system($cmd)==0 or err("Could not run: $cmd");
      $copied++;
    }
    my $missing = scalar($set->isolates) - $copied;
    msg("Pre-filled $copied '$file' files ($missing missing)");
  }
}

#.............................................................................
# start the log file
msg("Saving $outdir/$LOGFILE");
Nullarbor::Logger->save_log(">>$outdir/$LOGFILE");

#.............................................................................

#print Dumper(\%make);
msg("Writing Makefile");
my $makefile = "$outdir/Makefile";
open my $make_fh, '>', $makefile or err("Could not write $makefile");
write_makefile(\%make, $make_fh);
my $relout = path($outdir)->relative(getcwd())->canonpath;
my $MAXLOAD = max(1, num_cpus() - $threads);
my $run_cmd = "nice make -j $jobs -l $MAXLOAD -C $relout 2>&1 | tee -a $relout/$LOGFILE";
if ($run) {
  exec($run_cmd) or err("Could not run pipeline's Makefile");
}
else {
  msg("Run the pipeline with:");
  msg( colored("$run_cmd", "bold") );
}

msg("Done.");
exit(0);

#----------------------------------------------------------------------
sub write_makefile {
  my($make, $fh) = @_;
  $fh = \*STDOUT if not defined $fh;

  print $fh "# Command line:\n# cd ".getcwd()."\n# @CMDLINE\n\n";

  print $fh "BINDIR := $FindBin::RealBin\n";
  print $fh "CPUS := $threads\n";
  print $fh "REF := $ref\n";
  print $fh "NAME := $name\n";
  print $fh "PUBLISH_DIR := ", $cfg->{publish}, "\n";
  print $fh "ASSEMBLER := cpus=\$(CPUS) opts=\"$assembler_opt\" ", $plugin->{assembler}{$assembler}, "\n";
  print $fh "TREEBUILDER := cpus=\$(CPUS) opts=\"$treebuilder_opt\" ", $plugin->{treebuilder}{$treebuilder}, "\n";
  print $fh "TAXONER := cpus=\$(CPUS) opts=\"$taxoner_opt\" ", $plugin->{taxoner}{$taxoner}, "\n";
  print $fh "NW_DISPLAY := nw_display ".($cfg->{nw_display} || '')."\n";
  print $fh "GCODE := $gcode\n";
  print $fh "PROKKA := prokka --centre X --compliant --force".($fullanno ? " --fast" : "")."\n";
  print $fh "SNIPPY := snippy --force\n";
  print $fh "SNIPPYCORE := snippy-core".($mask ? " --mask $mask\n" : "\n");
  print $fh "ROARY := roary -v\n";
  print $fh "ABRICATE := abricate\n";
  print $fh "MLST := mlst\n";
  print $fh "MASH := mash\n";

  # copy any header stuff from the __DATA__ block at the end of this script
  while (<DATA>) {
    s/^[ ]+/\t/;  # indents to tabs
    print $fh $_;
  }
  
  for my $target ('all', sort grep { $_ ne 'all' } keys %$make) {
    print $fh "\n";
    my $rule = $make->{$target}; # short-hand
    my $dep = $rule->{DEP};
    $dep = ref($dep) eq 'ARRAY' ? (join ' ', @$dep) : $dep;
    $dep ||= '';
    print $fh ".PHONY: $target\n" if $rule->{PHONY} or ! $rule->{DEP};
    print $fh "$target : $dep\n";
    if (my $cmd = $rule->{CMD}) {
      my @cmd = ref $cmd eq 'ARRAY' ? @$cmd : ($cmd);
      print $fh map { "\t$_\n" } @cmd;
    }
  }
}

#-------------------------------------------------------------------

sub default_string {
  my($def, @list) = @_;
  return join( ' ', sort @list )." ($def)";
#  return join( ' ', map { $_ eq $def ? ">>$_<<" : $_ } sort @list );
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
  print "    --fullanno               Don't use --fast for Prokka\n";
  print "    --prefill                Prefill precomputed data via [prefill] via --conf\n";
  print "    --mask BED | auto        Mask core SNPS in these regions or 'auto' ($mask)\n";
#  print "    --keepfiles              Keep ALL ancillary files to annoy your sysadmin\n";
#  print "COMPONENTS [NOT WORKING]\n";
#  print "    --disable-pangenome      Don't generate pan-genome with Roary\n"
#  print "    --enable-cfml            Mask recombination with ClonalFrameML\n"
  print "PLUGINS\n";
  print "    --assembler NAME         Assembler to use: ", default_string( $assembler, keys(%{$plugin->{assembler}}) ), "\n";
  print "    --assembler-opt STR      Extra assembler options to pass ($assembler_opt)\n";
  print "    --treebuilder NAME       Tree-builder to use: ", default_string( $treebuilder, keys(%{$plugin->{treebuilder}}) ), "\n";
  print "    --treebuilder-opt STR    Extra tree-builder options to pass ($treebuilder_opt)\n";
  print "    --taxoner NAME           Species ID tool to use: ", default_string( $taxoner, keys(%{$plugin->{taxoner}}) ), "\n";
  print "    --taxoner-opt STR        Extra species ID builder options to pass ($taxoner_opt)\n";
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

  require_perlmod( qw'Bio::SeqIO Cwd Sys::Hostname Time::Piece List::Util Path::Tiny YAML::Tiny' );
  require_perlmod( qw'Moo Term::ANSIColor Path::Tiny File::Copy File::Spec File::Path Data::Dumper' );

  require_exe( qw'head cat install env nl grep touch' );
  require_exe( qw'seqtk trimmomatic prokka roary snippy mlst abricate seqret' );
  require_exe( qw'skesa megahit spades.py shovill nw_order nw_display iqtree FastTree snp-dists' );
  require_exe( qw'kraken kraken-report centrifuge centrifuge-kreport' );
  require_exe( qw'fq fa roary2svg.pl' );

  require_version('shovill', 0.9);
  require_version('megahit', 1.1);
  require_version('skesa', 2.1);
  require_version('snippy', 4.0);
  require_version('prokka', 1.12);
  require_version('roary', 3.0, undef, '-w'); # uses -w
  require_version('mlst', 2.10);
  require_version('abricate', 0.8);
  require_version('snp-dists', 0.6, undef, '-v'); # supports -v not --version
  require_version('trimmomatic', 0.36, undef, '-version'); # supports -version not --version
  require_version('spades.py', 3.12); 
  require_version('kraken', 1.0);
  require_version('centrifuge', 1.0);

  my $value = require_var('KRAKEN_DEFAULT_DB', 'kraken');
  require_file("$value/database.idx", 'kraken');
  require_file("$value/database.kdb", 'kraken');
  
  my $cdb = require_var('CENTRIFUGE_DEFAULT_DB', 'centrifuge');
  require_file("$cdb.$_.cf", 'centrifuge') for (1..3);

  msg( colored("All $EXE $VERSION dependencies are installed.", "bold") );
  msg("You deserve a medal!");
}

#-------------------------------------------------------------------

__DATA__

SHELL := /bin/bash
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

.SUFFIXES:
.DELETE_ON_ERROR:
.SECONDARY:
.ONESHELL:
.DEFAULT: all
.PHONY: all info clean publish

ISOLATES := $(shell cat isolates.txt)
CONTIGS := $(addsuffix /contigs.fa,$(ISOLATES))
GFFS := $(addsuffix /contigs.gff,$(ISOLATES))
SNIPPY_VCFS := $(addsuffix /snps.vcf,$(ISOLATES))
NAMED_GFFS := $(addsuffix .gff,$(ISOLATES))

FASTAREF := ref.fa
VIRULOME_DB := vfdb
RESISTOME_DB := ncbi

all : isolates.txt report/index.html

info :
  @echo CPUS: $(CPUS)
  @echo REF: $(REF)

report/index.html : ref.fa.fai yield denovo.tab mlst.tab virulome resistome kraken core.svg distances.tab roary/pan.svg roary/acc.svg
  nullarbor-report.pl --name $(NAME) --indir . --outdir report

publish : report/index.html
  mkdir -p $(PUBLISH_DIR)/$(NAME)
  install -p -D -t $(PUBLISH_DIR)/$(NAME) report/*
  
$(FASTAREF) : $(REF)
  seqret -auto -filter -osformat2 fasta < $< > $@
  touch --reference=$< $@

virulome : $(addsuffix /virulome.tab,$(ISOLATES))

resistome : $(addsuffix /resistome.tab,$(ISOLATES)) 

kraken : $(addsuffix /kraken.tab,$(ISOLATES)) 

yield : $(addsuffix /yield.tab,$(ISOLATES)) 

mlst.tab : $(CONTIGS)
  mlst $^ > $@

denovo.tab : $(CONTIGS)
  fa -e -t $^ > $@  

distances.tab : core.aln
  snp-dists -b $< > $@

%/snps.vcf : $(REF) %/R1.fq.gz %/R2.fq.gz
  $(SNIPPY) --cpus $(CPUS) --outdir $(@D)/snippy --ref $(word 1,$^) --R1 $(word 2,$^) --R2 $(word 3,$^)
  cp -vf $(@D)/snippy/snps.{tab,aligned.fa,vcf,bam,bam.bai,log} $(@D)/
  rm -fr $(@D)/snippy

core.aln : $(FASTAREF) $(SNIPPY_VCFS)
  $(SNIPPYCORE) --ref $< $(ISOLATES)

%.gff : %/contigs.gff
  ln -f $< $@

roary/gene_presence_absence.csv roary/accessory_binary_genes.fa.newick : $(NAMED_GFFS)
  $(ROARY) -f roary -p $(CPUS) -t $(GCODE) $^
  rm -f $(NAMED_GFFS)

roary/pan.svg : roary/gene_presence_absence.csv
  roary2svg.pl $< > $@

roary/acc.svg : roary/accessory_binary_genes.fa.newick
  $(NW_DISPLAY) $< > $@

%/kraken.tab : %/R1.fq.gz %/R2.fq.gz
  read1="$(word 1,$^)" read2="$(word 2,$^)" outfile="$@" $(TAXONER)

%/contigs.gff: %/contigs.fa
  $(PROKKA) --locustag $(@D) --prefix contigs --outdir $(@D)/prokka --cpus $(CPUS) --gcode $(GCODE) $<
  cp -vf $(@D)/prokka/contigs.gff $@
  cp -vf $(@D)/prokka/contigs.gbk $(@D)
  rm -fr $(@D)/prokka

%/contigs.fa : %/R1.fq.gz %/R2.fq.gz
  read1="$(word 1,$^)" read2="$(word 2,$^)" outdir="$(@D)" $(ASSEMBLER)

%/yield.tab : %/R1.fq.gz %/R2.fq.gz
  fq --quiet --ref $(FASTAREF) $^ > $@

%/resistome.tab : %/contigs.fa
  $(ABRICATE) --db $(RESISTOME_DB) $^ > $@

%/virulome.tab : %/contigs.fa
  $(ABRICATE) --db $(VIRULOME_DB) $^ > $@

%/sketch.msh : %/R1.fq.gz %/R2.fq.gz
  $(MASH) sketch -p $(CPUS) -o $(basename $@) -m 3 -r $<

%.svg : %.newick
  $(NW_DISPLAY) $< > $@

%.newick : %.aln
  aln="$(<)" tree="$(@)" $(TREEBUILDER)

%.fa.fai : %.fa
  samtools faidx $<

panic : $(BINDIR)/../conf/motd.txt
  @cat $<

help : $(BINDIR)/../conf/make_help.txt
  @cat $<

list : isolates.txt
  @nl $<
