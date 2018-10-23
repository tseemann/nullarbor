#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use Module::Load;
use Cwd qw(realpath getcwd);
use Path::Tiny;
use File::Copy;

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
  "name=s"   => \$name,
  "indir=s"  => \$indir,
  "outdir=s" => \$outdir,
  "preview"  => \$preview,
) 
or usage();

#.................................................................................
# process parameters

Nullarbor::Logger->quiet($quiet);

msg("Hello", $ENV{USER} || 'stranger');
msg("This is $EXE $VERSION");
msg("Send complaints to $AUTHOR");

$name or err("Please provide a --name for the report");
$name =~ m{/|\s} and err("The --name is not allowed to have spaces or slashes in it.");
$indir or err("Please set the --indir Nullarbor folder");
$outdir or err("Please set the --outdir output folder.");

$indir = realpath($indir);
$outdir = realpath($outdir);

if (-d $outdir) {
  msg("Folder --outdir $outdir already exists.");
}
else {
  msg("Making folder --outdir $outdir");
  path($outdir)->mkpath or err("Could not create folder: $outdir");
}

#-------------------------------------------------------------------
# main() 

my @ids = path("$indir/isolates.txt")->lines({chomp=>1});
msg("Identified", scalar(@ids), "isolates.");

my $MAGIC = '~~~MENU~~~';
my @menu;

my @html;
push @html, path("${TEMPLATE_DIR}/report.header.html")->slurp;
push @html, "<h1>$name</h1>\n";

my @section = qw(jobinfo seqdata identification mlst serotype resistome virulome
                 assembly reference core phylotree snpdist snpdensity pan
                 tools databases about);

if ($preview) {
  @section = qw(jobinfo mashtree about);
}

for my $section (@section) {
  msg("Generating: $section");
  my $modname = "Nullarbor::Module::$section";
  load $modname;
  my $module = $modname->new(indir=>$indir, outdir=>$outdir, id=>$section, report=>$name, isolates=>\@ids);
  my $result = $module->html;
  if (not $result) {
    msg("WARNING: no analysis available for $section");
    next;
  }
  push @html, "<div class='container-fluid nullarbor-section' id='$section'>\n<a name='$section'></a>\n" .
              "<h2>$MAGIC".$module->name." <a href='#' class='jump-home'>&#x25B2;</a> </h2>\n" .
              $result .
              "</div>";
  # keep track of sections
  push @menu, "<a href='#$section'>".$module->name."</a>";
}

push @html, path("${TEMPLATE_DIR}/report.footer.html")->slurp;

my $menu = dropdown_menu(@menu);
foreach (@html) {
  s/$MAGIC/$menu/;
}

my $out_fn = "$outdir/index.html";
path($out_fn)->spew(@html);

copy("${TEMPLATE_DIR}/nullarbor.css", $outdir);

msg("Results in: $out_fn");
msg("Done.");

#-------------------------------------------------------------------
sub dropdown_menu {
  my(@items) = @_;
  my $html = "<span class='dropdown'>\n";
  $html .= "<button class='btn btn-default dropdown-toggle' type='button' data-toggle='dropdown'>&#9776;</button>\n";
  $html .= "<ul class='dropdown-menu'>". join('', map { "<li>$_\n" } @menu) . "</ul>";
  $html .= "</span>\n";
  return $html;
}

#-------------------------------------------------------------------
sub usage {
  print "NAME\n";
  print "  $EXE $VERSION\n";
  print "SYNOPSIS\n";
  print "  Generate a HTML report from a Nullabor results folder\n";
  print "AUTHOR\n";
  print "  $AUTHOR\n";
  print "USAGE\n";
  print "  $EXE [options] --name NAME --indir NULLARBOR_DIR --outdir REPORT_DIR\n";
  print "    --name      Report name to put in the top heading\n";
  print "    --indir     Nullarbor result folder\n";
  print "    --outdir    Folder to build report HTML in\n";
  print "    --preview   Quick summary after 'make preview'\n";
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

