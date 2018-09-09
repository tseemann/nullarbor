package Nullarbor::Module::assembly;
use Moo;
extends 'Nullarbor::Module';

#...........................................................................................

my $CONTIG_MULT = 1.5;
my $BP_DEV = 0.2;

#...........................................................................................

sub name {
  return "Assembly and annotation";
}

#...........................................................................................

sub extract_insert_size {
  my($fname) = @_;
  open BWALOG, '<', $fname or return 'n/a';
  while (<BWALOG>) {
    if (m/insert size distribution for orientation FR/) {
      # [M::mem_pestat] (25, 50, 75) percentile: (143, 214, 323)
      my $stats = <BWALOG>;
      chomp $stats;
      $stats =~ s/^.*\(/\(/;
      return $stats;
    }
  }
  close BWALOG;
  return 'N/A';
}

#...........................................................................................

sub gff_ftype_count {
  my($gff) = @_;
  my %count;
  open my $GFF, '<', $gff;
  while (<$GFF>) {
    next if m/^#/;  # header - comments
    last if m/^>/;  # footer - FASTA
    my(undef,undef,$ftype) = split m/\t/;
    $count{$ftype}++ if defined $ftype;
  }
  return \%count;
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;

  my $ass = Nullarbor::Tabular::load(-file=>"$indir/denovo.tab", -sep=>"\t", -header=>1);
  $ass->[0][0] = 'Isolate';
  $ass->[0][1] = 'Contigs';
  map { $_->[0] =~ s{/contigs.fa}{} } @$ass;
  
  # extract insert size from BWA output in Snippy folder
###  push @{$ass->[0]}, "Insert size (25,50,75)%";
  my @annofeat = qw(CDS rRNA tRNA tmRNA);
  push @{$ass->[0]}, @annofeat;
  push @{$ass->[0]}, "Quality";

  my $mean_ctgs = Nullarbor::Tabular::column_average($ass, 1, "%d");
  my $mean_bp = Nullarbor::Tabular::column_average($ass, 2, "%d");
  
  for my $row (1 .. @$ass-1) {
    my $id = $ass->[$row][0];
###    # embed BWA MEM insert size results (v1 vs v2)
###    my $snplog = -r "$indir/$id/snps.log" ? "$indir/$id/snps.log" : "$indir/$id/$id/snps.log";
###    push @{ $ass->[$row] }, extract_insert_size($snplog);
    # embed prokka results in table
    my $prokka = "$indir/$id/prokka/$id";
    if (-r "$prokka.txt") {   # version 1.x
      my %anno = (map { ($_->[0] => $_->[1]) } @{ Nullarbor::Tabular::load(-file=>"$prokka.txt", -sep=>': ') } );
      push @{ $ass->[$row] }, (map { $anno{$_} } @annofeat);
    }
    elsif (-r "$id/contigs.gff") {   # version 2.x
      my $count = gff_ftype_count("$id/contigs.gff");
      for my $ftype (@annofeat) {
        push @{ $ass->[$row] }, $count->{$ftype} || 0;
      }
    }
    # final traffic light
    my($ctgs, $bp) = @{$ass->[$row]}[1,2];
    my $bad = ($ctgs > 999) || ($ctgs > ${CONTIG_MULT}*$mean_ctgs) || ($bp < (1.0-$BP_DEV)*$mean_bp) || ($bp > (1.0+$BP_DEV)*$mean_bp);
    push @{$ass->[$row] }, $self->pass_fail( $bad ? -1 : +1 );
  }
  
  return $self->table_legend("Typical", 
                             "&mu;<SUB>Contigs</SUB>=$mean_ctgs &and; &mu;<SUB>bp</SUB>=$mean_bp", 
                             "Contigs &gt; ${CONTIG_MULT}&mu; &or; bp &plusmn; ${BP_DEV}&mu;")
        .$self->matrix_to_html($ass);
}
  

#...........................................................................................

1;

