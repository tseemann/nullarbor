package Nullarbor::Logger;

use base Exporter;
@EXPORT_OK = qw(msg err wrn);

use Time::Piece;
use Term::ANSIColor;

our $quiet = 0;
our @log;

#----------------------------------------------------------------------

sub get_log {
  return @log;
}

#----------------------------------------------------------------------

sub reset_log {
  @log = ();
}

#----------------------------------------------------------------------

sub save_log {
  my($self, $fopen) = @_;
  open OUT, $fopen or err("Could not save log file to '$fopen'");
  print OUT @log;
  close OUT;
}

#----------------------------------------------------------------------

sub quiet {
  my($self, $value) = @_;
  $quiet = $value if $value;
  return $quiet;
}

#----------------------------------------------------------------------

sub msg {
  my $t = localtime;
  my $line = "[".$t->hms."] @_\n";
  push @log, $line;
  print STDERR $line unless $quiet;
}
      
#----------------------------------------------------------------------

sub wrn {
  msg("WARNING:", @_);
}

#----------------------------------------------------------------------

sub err {
  msg("ERROR:", @_);
  exit(1);
}

#----------------------------------------------------------------------

1;

