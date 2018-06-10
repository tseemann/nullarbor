package Nullarbor::Plugins;

use base Exporter;
@EXPORT_OK = qw();

use Data::Dumper;
use Nullarbor::Logger qw(msg err);

my $RUNNER_DIR = "$FindBin::RealBin/../plugins";
my $IGNORE = "common.inc";

#----------------------------------------------------------------------

sub discover { 
  my($self,$dir) = @_;
  $dir ||= $RUNNER_DIR;  
#  msg("Checking plugins in $dir");
  my $p = {};
  while (my $script = <$dir/*/*.sh>) {
    next unless -x $script;
    $script =~ m{^.*?/(\w+)/(\w+).sh$} or err("Can't parse plugin from: $script");    
    my($class,$name) = ($1,$2);
    $p->{$class}{$name} = $script;
#    msg("Found plugin: $class/$name");
  }
  return $p;
}

#----------------------------------------------------------------------

1;

