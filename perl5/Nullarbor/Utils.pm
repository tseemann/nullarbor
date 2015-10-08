package Nullarbor::Utils;

use base Exporter;
@EXPORT_OK = qw(num_cpus);

#----------------------------------------------------------------------

sub num_cpus { 
 my($num)= qx(getconf _NPROCESSORS_ONLN); # POSIX
 chomp $num;
 return $num || 1;
}

#----------------------------------------------------------------------

1;

