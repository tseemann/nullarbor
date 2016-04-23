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
  my $pan_png = "$roary/roary.png";
  my $pan_svg = "$roary/roary.png.svg";
  my $acc_tree = "$roary/accessory_binary_genes.fa.newick";
  my $acc_svg = "$roary/accessory_binary_genes.fa.newick.svg";

  return unless -r $pan_ss and -r $pan_png;
  
  my $html = '';

  copy($pan_png, "$outdir/pan.png");
  $html .= "<img src='pan.png'>\n";
  
  my $ss = Nullarbor::Tabular::load(-file=>$pan_ss, -sep=>"\t");
  unshift @$ss, [ "Ortholog class", "Definition", "Count" ];
  $html .= $self->matrix_to_html($ss, 1);
 
  my $svg = $self->load_svg($acc_svg);
  $html .= "<p class='container-fluid'>\n$svg\n</p>\n";
  
  return $html;
}


#...........................................................................................

1;

