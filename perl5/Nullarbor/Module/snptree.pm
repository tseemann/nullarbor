package Nullarbor::Module::snptree;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................

sub name {
  return "Core SNP phylogeny";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
#  my $outdir = $self->outdir;
#  my $name = $self->name;
  my $html = '';

  my $nwk = -r "core.newick" ? "core.newick" : "tree.newick";
  my $svg = -r "core.svg" ? "core.svg" : "tree.svg";

  $html .= $self->download_links("core.aln", $nwk);
  
  my $svg_data = $self->load_svg("$indir/$svg");
  $html .= "<p class='container-fluid'>\n$svg_data\n</p>\n";

  my $aln = Bio::SeqIO->new(-file=>"$indir/core.aln", -format=>'fasta');
  $aln = $aln->next_seq;
  $html .= sprintf "Core SNP alignment has %d taxa and %s bp. ", scalar(@{$self->isolates}), $aln->length;

  return $html;
}

#...........................................................................................

1;

