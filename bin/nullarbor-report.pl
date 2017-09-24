#!/usr/bin/env perl
use strict;
use warnings;

#-------------------------------------------------------------------
# libraries

use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path);
use File::Slurp;
use Module::Load;
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
my $VERSION = '1.25';
my $AUTHOR = 'Torsten Seemann <torsten.seemann@gmail.com>';
my @CMDLINE = ($0, @ARGV);

#-------------------------------------------------------------------
# parameters

my $verbose = 0;
my $quiet   = 0;
my $name = '';
my $indir = '';
my $outdir = '';

@ARGV or usage();

GetOptions(
  "help"     => \&usage,
  "version"  => \&version, 
  "verbose"  => \$verbose,
  "quiet"    => \$quiet,
  "name=s"   => \$name,
  "indir=s"  => \$indir,
  "outdir=s" => \$outdir,
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

$indir = File::Spec->rel2abs($indir);
$outdir = File::Spec->rel2abs($outdir);

if (-d $outdir) {
  msg("Folder --outdir $outdir already exists.");
}
else {
  msg("Making folder --outdir $outdir");
  make_path($outdir);
}

#-------------------------------------------------------------------
# main() 

my @ids = read_file("$indir/isolates.txt");
chomp @ids;
msg("Identified", scalar(@ids), "isolates.");

my $MAGIC = '~~~MENU~~~';
my @menu;

my @html;
push @html, scalar read_file("${TEMPLATE_DIR}/report.header.html");
push @html, "<h1>$name</h1>\n";

my @section = qw(jobinfo seqdata identification mlst serotype resistome virulome
                 assembly reference core snptree snpdist snpdensity pan
                 tools about);

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

push @html, scalar read_file("${TEMPLATE_DIR}/report.footer.html");

my $menu = dropdown_menu(@menu);
foreach (@html) {
  s/$MAGIC/$menu/;
}

my $out_fn = "$outdir/index.html";
write_file($out_fn, @html);

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
  print "    --name      Check dependencies only\n";
  print "    --indir     Nullarbor result folder\n";
  print "    --outdir    Folder to build report HTML in\n";
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

