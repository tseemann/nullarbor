package Nullarbor::Module::pan;
use Moo;
extends 'Nullarbor::Module';

use File::Copy;

#...........................................................................................

sub name {
  return "Pan genome";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $roary = $self->indir . "/roary";
  my $outdir = $self->outdir;
  
  my $pan_ss = "$roary/summary_statistics.txt";

  my $pan_svg = -r "$roary/pan.svg" 
              ? "$roary/pan.svg" 
              : "$roary/roary.png.svg";

  my $acc_svg = -r "$roary/acc.svg" 
              ? "$roary/acc.svg"
              : "$roary/accessory_binary_genes.fa.newick.svg";

  for my $need ($pan_ss, $pan_svg, $acc_svg) {
    return unless -r $need;
  }
  
  my $html = '';

#  copy($pan_png, "$outdir/pan.png");
#  $html .= "<img src='pan.png'>\n";
  my $svg1 = $self->load_svg($pan_svg);
  $html .= "<p class='container-fluid'>\n$svg1\n</p>\n";
  
  my $ss = Nullarbor::Tabular::load(-file=>$pan_ss, -sep=>"\t");
  unshift @$ss, [ "Ortholog class", "Definition", "Count" ];
  $html .= $self->matrix_to_html($ss, 1);

  my $svg2 = $self->load_svg($acc_svg);
  $html .= "<p class='container-fluid'>\n$svg2\n</p>\n";
  
  return $html;
}


#...........................................................................................

1;

