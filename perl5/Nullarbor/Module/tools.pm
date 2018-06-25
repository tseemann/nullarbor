package Nullarbor::Module::tools;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................
# shell snippet to extract version on FIRST line of output (stderr or stdout ook)

my %getver = (
  'Nullarbor' => 'nullarbor.pl --version',
  'MLST' => 'mlst --version',
  'Abricate' => 'abricate --version',
  'Snippy' => 'snippy --version',
  'Kraken' => 'kraken --version',
  'SAMtools' => 'samtools --version',
  'FreeBayes' => 'freebayes --version',
  'MegaHit' => 'megahit --version',
  'Prokka', => 'prokka --version',
  'IQtree', => 'iqtree --version',
  'Shovill', => 'shovill --version',
  'Roary' => 'roary -w 2>&1 | grep "^[1-9]"',
  'Trimmomatic' => 'trimmomatic -version 2>&1 | grep -v _JAVA',
  'SPAdes' => 'spades.py --help',
  'BWA MEM' => 'bwa 2>&1 | grep ^Version',
  'FastTree' => 'FastTree',
  'Newick-Utils' => 'echo 1.6',  # hasn't been updated in ages
  'SKESA' => 'skesa --version 2>&1 | grep SKESA',
  'snp-dists' => 'snp-dists -v',
  'seqret' => 'seqret -h 2>&1 | grep ^Version',
  'seqtk' => 'seqtk 2>&1 | grep ^Version',
  'centrifuge' => 'centrifuge --version 2>&1 | sed "s/^.*version //"',
);

#...........................................................................................

sub name {
  return "Software versions";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
  
  my @inv = ( [ "Tool", "Version" ] );
  for my $tool (sort keys %getver) {
    my($ver) = qx($getver{$tool} 2>&1);
    chomp $ver;
#    $ver =~ s/^.*?(?=\d)//g; # skip over anything not numeric
    $ver =~ s/^\D*//g; # skip over anything not numeric
    $ver ||= '(unable to determine version)';
    push @inv, [ $tool, $ver ];
  }
  
  return $self->matrix_to_html(\@inv, 1);
}

#...........................................................................................

1;
