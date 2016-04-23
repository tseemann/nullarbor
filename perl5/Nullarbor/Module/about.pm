package Nullarbor::Module::about;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................

sub name {
  return "About";
}

#...........................................................................................

sub html {
  my($self) = @_;
  return qq{
<ul class='list-unstyled'>
<li>This primary author of Nullarbor is <a href="http://tseemann.github.io/">Torsten Seemann</a>.
<li>You can download the software from <a href="https://github.com/tseemann/nullarbor">Github</a>.
<li>Please report bugs at the <a href="https://github.com/tseemann/nullarbor/issues">Nullarbor Issue Tracker</a>.
<li>If you use Nullarbor please use the <a href="https://github.com/tseemann/nullarbor/#citation">latest citation</a>.
</ul>
  }
}

#...........................................................................................

1;

