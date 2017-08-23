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
  'Roary' => 'roary --version',
  'Trimmomatic' => 'trimmomatic -version',
  'SPAdes' => 'spades.py --help',
  'BWA MEM' => 'bwa 2>&1 | grep ^Version',
  'FastTree' => 'FastTree',
  'Newick-Utils' => 'echo',
  'snp-dists' => 'snp-dists -v',
  'seqret' => 'seqret -h 2>&1 | grep ^Version',
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
