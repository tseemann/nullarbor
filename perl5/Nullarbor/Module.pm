package Nullarbor::Module;
use Moo;

use Nullarbor::Logger qw(msg err);
use Nullarbor::Tabular;
use File::Copy;
use Data::Dumper;
use Path::Tiny;

#.................................................................................

has indir    => ( is => 'ro' );
has outdir   => ( is => 'ro' );
has report   => ( is => 'ro' );
has isolates => ( is => 'ro' );
has id       => ( is => 'ro' );
#.................................................................................

sub download_links {
  my($self, @file) = @_;
  my $html = "<span class='file-download-bar'>Download: ";
  for my $file (@file) {
    $html .= " <a href='$file' class='file-download'>&#11015;$file</a>";
    copy($self->indir."/$file", $self->outdir) if not -r $self->outdir."/$file";
  }
  return $html."</span>\n";
}

#.................................................................................

sub matrix_to_html {
  my($self, $matrix, $plain) = @_;
  my $id = $self->id;
  # choose between regular Bootstrap tables or DataTables
  my $class = $plain ? "table table-bordered table-condensed" : "display compact table-sortable";
  my $html = "<table id='$id' class='$class'>\n<thead>\n";
  my $row_no=0;
  my $nuke_last_col = $matrix->[0][-1] eq 'Quality';  # remove the Quality column from CSV
  for my $row (@$matrix) {
    #pop(@$row) if $nuke_last_col;
    $html .= "<tr>\n";
    my $td = $row_no==0 ? "<th>" : "<td>";
    for my $col (@$row) {
      $col = '' if not defined $col;
      $html .= "$td$col\n";
    }
    $html .= "</thead>\n<tbody>\n" if $row_no==0;
    $row_no++;
  }
  $html .= "</tbody>";

  my $csv_fn = $self->id.".csv";
  path($self->outdir."/$csv_fn")->spew( $self->matrix_to_csv($matrix) );
  $html .= "<caption>" . 
           $self->download_links($csv_fn) . 
#           " | <button id='go-plain' type='button' class='btn btn-primary active' data-toggle='button' aria-pressed='true' autocomplete='off'>Fancy</button>" .
           "</caption>\n";

  $html .= "</table>\n";

  return $html;
}

#.................................................................................

sub matrix_to_csv {
  my($self, $matrix, $sep) = @_;
  $sep ||= ",";
  my $csv = '';
  for my $row (@$matrix) {
    # replace $sep with ~ / remove HTML
    $csv .= join($sep, map { local $_ = $_; s/<[^>]*>//g; s/$sep/~/g; $_ } @$row)."\n";
  }
  return $csv;
}

#.................................................................................

sub pass_fail {
    my($self, $level, $alt_text) = @_;
    $level ||= 0;
    my $sym = '?';
    my $class = 'dunno';
    if ($level < 0) {
      $sym = "&#10008;";
      $class = 'fail';
    }
    elsif ($level > 0) {
      $sym = "&#10004;";
      $class = 'pass';
    }
    my $alt = defined($alt_text) ? " title='$alt_text'" : "";
    return "<span class='traffic-light $class'$alt>$sym</span>";
}


#.................................................................................

sub table_legend {
  my($self, $pass,$ok,$fail) = @_;  # labels
  $pass ||= 'Pass';
  $ok ||= 'OK';
  $fail ||= 'Fail';
  my $SPAN = "<SPAN CLASS='legend-item'>";
  my $html = "<B>Legend:</B>\n"
           . $SPAN.$self->pass_fail(+1, $pass). " $pass</SPAN>\n"
           . $SPAN.$self->pass_fail(0,    $ok). " $ok</SPAN>\n"
           . $SPAN.$self->pass_fail(-1, $fail). " $fail</SPAN>\n"
           ;
  return "<SPAN CLASS='legend'>\n$html\n</SPAN>\n";           
}

#.................................................................................
# load a .SVG file and fix headers to work better as inline <SVG>
# FIXME: should probably use XML::Simple or another module....
# https://css-tricks.com/scale-svg/
# ?xml version='1.0' standalone='no'?><!DOCTYPE svg PUBLIC '-//W3C//DTD SVG
# 1.1//EN' 'http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd'><svg
# width='1024' height='136' version='1.1' xmlns='http://www.w3.org/2000/svg'
# xmlns:xlink='http://www.w3.org/1999/xlink' >

sub load_svg {
  my($self, $svg_fn) = @_;

  my $xml = path("$svg_fn")->slurp or err("Could not open SVG file: $svg_fn");
    
  $xml =~ m/\bwidth=['"]?(\d+)['"]?/;
  my $w = $1 || 1024;

  $xml =~ m/\bheight=['"]?(\d+)['"]?/;
  my $h = $1 || 512;
  
  $xml =~ s/^.*?<svg/<svg viewBox="0 0 $w $h"/;

  return $xml;
}

#.................................................................................

1;




