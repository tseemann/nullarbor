package Nullarbor::Module::mashtree;
use Moo;
extends 'Nullarbor::Module';

#...........................................................................................

use Nullarbor::Logger qw(msg err);

#...........................................................................................

sub name {
  return "Preview tree";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $outdir = $self->outdir;

  my $svg = $self->indir . "/preview.svg";
  -r $svg or err("Could not open SVG: $svg");  

  my $html = '';

  my $SVG = $self->load_svg($svg);
  $html .= "<p class='container-fluid'>\n$SVG\n</p>\n";
  
  return $html;
}


#...........................................................................................

1;
