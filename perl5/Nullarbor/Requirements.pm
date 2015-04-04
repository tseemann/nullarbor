package Nullarbor::Requirements;

use base Exporter;
@EXPORT_OK = qw(require_exe require_perlmod);

use File::Spec;
use Nullarbor::Logger qw(err msg);

#----------------------------------------------------------------------
sub require_exe {
  my(@arg) = @_;
  for my $exe (@arg) {
    my $where = '';
    for my $dir ( File::Spec->path ) {
      if (-x "$dir/$exe") {
        $where = "$dir/$exe";
        last;
      }
    }
    if ($where) {
      msg("Found '$exe' => $where");
    }
    else {
      err("Could not find '$exe'. Please install it and ensure it is in the PATH.");
    }
  }
  return;
}

#----------------------------------------------------------------------
sub require_perlmod {
  my (@arg) = @_;
  for my $mod (@arg) {
    my $rc = system("perl -e 'use $mod;'");
    if ($rc) {
      err("Could not Perl module '$mod'. Please install it. Try 'cpan -i $mod'.");
    }
    else {
      msg("Found Perl module: $mod");
    }
  }
  return;
}

#----------------------------------------------------------------------

1;

