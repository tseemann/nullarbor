package Nullarbor::Plugins;

use base Exporter;
@EXPORT_OK = qw();

use File::Slurp;
use Data::Dumper;
use Nullarbor::Logger qw(msg err);

my $RUNNER_DIR = "$FindBin::Bin/../plugins";
my $IGNORE = "common.inc";

#----------------------------------------------------------------------

sub discover { 
  my($self,$dir) = @_;
  $dir ||= $RUNNER_DIR;
  
  my $p = {};
  for my $class ( read_dir($dir) ) {
    next unless -d "$dir/$class";
    for my $script ( read_dir("$dir/$class") ) {
      next unless $script =~ m/\.sh$/;
      my $fp = "$dir/$class/$script";
      next unless -x $fp;
      $script =~ s/\.sh$//;
      $p->{$class}{$script} = $fp;
    }
  }
  return $p;
}

#----------------------------------------------------------------------

1;

