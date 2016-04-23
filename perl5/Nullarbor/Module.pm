package Nullarbor::Module;
use Moo;

use Nullarbor::Logger qw(msg err);
use Nullarbor::Tabular;
use File::Copy;
use File::Slurp;

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
  my($self, $matrix, $header, $footer) = @_;
  my $html = "<table class='table table-condensed table-bordered table-hover'>\n";
  my $row_no=0;
  for my $row (@$matrix) {
    $html .= "<tr>\n";
    my $td = (($header && $row_no==0) or ($footer && $row_no==$#$matrix)) ? "<th>" : "<td>";
    for my $col (@$row) {
      $html .= "$td$col\n";
    }
    $row_no++;
  }

  my $csv_fn = $self->id.".csv";
  write_file( $self->outdir."/$csv_fn", $self->matrix_to_csv($matrix) );
  $html .= "<caption>" . $self->download_links($csv_fn) . "</caption>\n";

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

1;

