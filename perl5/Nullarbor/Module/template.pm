package Nullarbor::Module::reference;
use Moo;
extends 'Nullarbor::Module';

use Data::Dumper;
use Bio::SeqIO;

#...........................................................................................

sub name {
  return "Reference genome";
}

#...........................................................................................

sub html {
  my($self) = @_;
  my $indir = $self->indir;
  
  my $fin = Bio::SeqIO->new(-file=>"$indir/ref.fa", -format=>'fasta');
  my $refsize;
  my @ref;
  push @ref, [ qw(Sequence Length Description) ];
  while (my $seq = $fin->next_seq) {
    my $id = $seq->id;
    $id =~ s/\|/~/g;
    push @ref, [ $id, $seq->length, ($seq->desc || 'no description') ];
    $refsize += $seq->length;
  }
#  print STDERR Dumper($r, \@ref);
  my $ncontig = scalar @ref;
  if ($ncontig < 10) {
    print  $fh table_to_markdown(\@ref, 1);
  }
  else {
    print $fh "\n_Reference sequence names not shown as too many contigs ($ncontig)\n";
  }

#...........................................................................................

1;

__DATA__
package Nullarbor::Report;
use Moo;

use Nullarbor::Logger qw(msg err);
use Data::Dumper;
use File::Copy;
use Bio::SeqIO;
use List::Util qw(sum min max);

#.................................................................................

sub heading {
  my($fh, $title) = @_;
  msg("Generating report section: $title");
  print $fh "##$title\n"; # make H2 a link to index
}

#.................................................................................

sub generate {
  my($self, $indir, $outdir, $name) = @_;

  $name ||= $outdir;

  msg("Generating $name report in: $outdir");
  open my $fh, '>', "$outdir/index.md";
  copy("$FindBin::Bin/../conf/nullarbor.css", "$outdir/");  

  #...........................................................................................
  # Load isolate list

  my $isolates_fname = "$indir/isolates.txt";
  open ISOLATES, '<', $isolates_fname or err("Can not open $isolates_fname");
  my @id = <ISOLATES>;
  chomp @id;
  close ISOLATES;
  @id = sort @id;
  msg("Read", 0+@id, "isolates from $isolates_fname");
  #print Dumper(\@id); exit;

  #...........................................................................................
  # Heading

  my $user = $ENV{USER} || $ENV{LOGNAME} || 'anonymous';
  my $date = qx(date);
  chomp $date;
  
  # special +pandoc_title_block extension 
  print $fh "% Report: $name\n\n"; 

  my $meta_data = [
    [ "Report", "Isolates", "Author", "Date", "Folder" ],
    [ $name, scalar(@id), $user, $date, "<TT>$indir</TT>" ],
  ];
  print $fh table_to_markdown($meta_data, 1);

#  print $fh "__Report:__ $name\n";
#  print $fh "__Date:__ $date\n";
#  print $fh "__Author:__ $user\n";
#  printf $fh "__Isolates:__ %d\n", scalar(@id);

  #...........................................................................................
  # MLST (old)
  
  my $mlst_legend = [
    [ "Legend", "Meaning" ],
    [ "(n)", "exact intact allele" ],
    [ "(~n)", "novel allele similar to n" ],
    [ "(n?)", "partial match to known allele" ],
    [ "(n,m)", "multiple alleles" ],
    [ "(-)", "allele missing" ],
  ];

  my $mlst = load_tabular(-file=>"$indir/mlst.tab", -sep=>"\t", -header=>1);
#  print STDERR Dumper($mlst);
  
  for my $row (@$mlst) {
    $row->[0] =~ s{/contigs.fa}{};
    $row->[0] =~ s/ref.fa/Reference/;
    # move ST column to end to match MDU LIMS
    my($ST) = splice @$row, 2, 1;
    my $missing = sum( map { $row->[$_] eq '-' ? 1 : 0 } (1 .. $#$row) );
    push @$row, $ST;
#    push @$row, "**${ST}**";
#    push @$row, pass_fail( $missing==0 && $ST ne '-' ? +1 : $missing <= 1 ? 0 : -1 );
  }
  $mlst->[0][0] = 'Isolate';
  $mlst->[0][-1] = 'ST';

#  heading($fh, "MLST (old)");
#  save_tabular("$outdir/$name.mlst.csv", $mlst, ",");
#  print $fh "Download: [$name.mlst.csv]($name.mlst.csv)\n";
#  print $fh table_to_markdown($mlst_legend, 1);
#  print $fh "<P>\n";
#  print $fh table_to_markdown($mlst, 1);

  #...........................................................................................
  # MLST
  
  my $mlst2 = load_tabular(-file=>"$indir/mlst2.tab", -sep=>"\t", -header=>0);

  # find maximum width (#columns) amongst the rows  
  my $width = max( map { scalar(@$_) } @$mlst );

  for my $row (@$mlst2) {
    $row->[0] =~ s{/contigs.fa}{};
    $row->[0] =~ s/ref.fa/Reference/;
    my $ST = $row->[2];
    my $missing = $row->[2] eq '-' ? 1E9 : sum( map { $row->[$_] =~ m/[-~?]/ ? 1 : 0 } (3 .. $#$row) );
    for my $i (3 .. $#$row) {
      my $g = $row->[$i];
      $g =~ s/^_//; # fix bold bug for alleles ending in _ !
      $g =~ s/_$//;
      my $class = $g =~ m/[-?]/ ? "missing" : $g =~ m/~/ ? "novel" : "known";
      $row->[$i] = "<SPAN CLASS='allele $class'>$g</SPAN>";
    }
    while (@$row < $width) {
      push @$row, '.';  # padding
    }
#    print STDERR "ST=$ST N=$ngene missing=$missing\n";
    push @$row, pass_fail( $missing==0 && $ST ne '-' ? +1 : $missing <= 1 ? 0 : -1 );
  }

  # add header
  unshift @{$mlst2}, [ "Isolate", "Scheme", "Sequence<BR>Type", ("Allele")x($width-3), "Quality" ];

  heading($fh, "MLST");
  
  # these are the 'old style' tables for download ... FIXME (MDU legacy)
  save_tabular("$outdir/$name.mlst.csv", $mlst, ",");   
  print $fh "Download: [$name.mlst.csv]($name.mlst.csv)\n";
  
  print $fh table_to_markdown($mlst_legend, 1);
  print $fh "<P>\n";
  print $fh table_to_markdown($mlst2, 1);

  #...........................................................................................
  # (OPTIONAL) MENINGOTYPE

  my $menin_file = "$indir/meningotype.tab";
  if (-r $menin_file) {
    my $menin = load_tabular(-file=>$menin_file, -sep=>"\t", -header=>1);
    my $row_no = 0;
    for my $row (@$menin) {
      $row->[0] =~ s{/contigs.fa}{};
      my $missing = sum( map { $row->[$_] eq '-' ? 1 : 0 } (1 .. $#$row) );
      push @$row, $row_no++ == 0 ? "Quality" 
                                 : pass_fail( $missing==0 ? +1 : $missing==3 ? -1 : 0 );
    }
    heading($fh, "Meningotype");
    print $fh table_to_markdown($menin, 1);
  }

  #...........................................................................................
  # (OPTIONAL) NGMASTER

  my $ngmaster_file = "$indir/ngmaster.tab";
  if (-r $ngmaster_file) {
    my $menin = load_tabular(-file=>$ngmaster_file, -sep=>"\t", -header=>1);
    my $row_no = 0;
    for my $row (@$menin) {
      $row->[0] =~ s{/contigs.fa}{};
      my $missing = sum( map { $row->[$_] eq '-' ? 1 : 0 } (1 .. $#$row) );
      push @$row, $row_no++ == 0 ? "Quality" 
                                 : pass_fail( $missing==0 ? +1 : $missing==2 ? -1 : 0 );
    }
    heading($fh, "NG-MAST");
    print $fh table_to_markdown($menin, 1);
  }
    
  #...........................................................................................
  # Yields

  #for my $stage ('dirty', 'clean') {
  for my $stage ('clean') {
    heading($fh, "Sequence data");
    my @wgs;
    my $first=1;
    for my $id (@id) {
      my $t = load_tabular(-file=>"$indir/$id/yield.$stage.tab", -sep=>"\t");
      if ($first) {
        # make the headings for the table
        $t->[0][0] = 'Isolate';
        push @wgs, [ map { $_->[0] } @$t ];
        push @{$wgs[-1]}, "Quality";
        $first=0;
      }
      # copy the yield.tab fields across
      $t->[0][1] = $id;
      push @wgs, [ map { $_->[1] } @$t ];
      my $depth = $wgs[-1][-1];
      $depth =~ s/\D+$//;
      push @{$wgs[-1]}, pass_fail( $depth < 25 ? -1 : $depth < 50 ? 0 : +1 );
    }
  #  print Dumper(\@wgs);
    print $fh table_to_markdown(\@wgs, 1);
  }
    
  #...........................................................................................
  # Species ID
  heading($fh, "Sequence identification");
  sub trim { 
    my($s) = @_; 
    $s =~ s/^\s+//; 
    $s =~ s/\s+$//; 
    return $s; 
  }
  sub font_prop {
    my($text, $p) = @_;
    return $text if !defined($p) or $p !~ m/^\d/;
    my $extra = $p > 0.5 ? " font-weight: bold;" : "";
#    my $i = int( 60 * (1-$p) );
#    my $color = "rgb($i%,$i%,$i%)";
    my $color = $p < 0.01 ? "lightgray" : $p < 0.10 ? "gray" : "black";
    return "<SPAN STYLE='color: $color;$extra'>$text</SPAN>";
  }
  my $NM = 4;
  my @spec;
  push @spec, [ 'Isolate', (map { ("#$_ Match", "%") } (1.. $NM)), "Quality" ];
  for my $id (@id) {
    my $t = load_tabular(-file=>"$indir/$id/kraken.tab", -sep=>"\t");
    # sort by proportion
    my @s = sort { $b->[0] <=> $a->[0] } (grep { $_->[3] =~ m/^[US]$/ } @$t);
    push @spec, [ 
      $id, 
      (map { 
        font_prop( '_'.trim($s[$_][5] || 'None').'_' , $s[$_][0]/100.0 ), 
        font_prop( trim($s[$_][0] || '-'), $s[$_][0]/100.0 ) 
       } (0 .. $NM-1)),
      pass_fail( $s[0][3] eq 'U' || $s[0][0] < 65 ? -1 : $s[0][0] < 80 ? 0 : +1 ),
    ];  # _italics_ taxa names
  }
#  print Dumper(\@spec);
  print $fh table_to_markdown(\@spec, 1);


  #...........................................................................................
  # Assembly & Anno
  
  heading($fh, "Assembly & Annotation");
  my $ass = load_tabular(-file=>"$indir/denovo.tab", -sep=>"\t", -header=>1);
#  print STDERR Dumper($ass);
  $ass->[0][0] = 'Isolate';
  $ass->[0][1] = 'Contigs';
  map { $_->[0] =~ s{/contigs.fa}{} } @$ass;
  # extract insert size from BWA output in Snippy folder
  push @{$ass->[0]}, "Insert size (25,50,75)%";
  my @annofeat = qw(CDS rRNA tRNA tmRNA);
  push @{$ass->[0]}, @annofeat;
  push @{$ass->[0]}, "Quality";
  for my $row (1 .. @$ass-1) {
    my $id = $ass->[$row][0];
    # embed BWA MEM insert size results
    push @{ $ass->[$row] }, extract_insert_size("$indir/$id/$id/snps.log");
    # embed prokka results in table
    my %anno = (map { ($_->[0] => $_->[1]) } @{ load_tabular(-file=>"$indir/$id/prokka/$id.txt", -sep=>': ') } );
    push @{ $ass->[$row] }, (map { $anno{$_} } @annofeat);
    # final traffic light
    push @{$ass->[$row] }, pass_fail( $ass->[$row][1] > 1000 ? -1 : +1 );
  }
  print $fh table_to_markdown($ass,1);

  #...........................................................................................
  # Annotation

if (0) {  
  heading($fh, "Annotation");
  my %anno;
  for my $id (@id) {
    $anno{$id} = { 
      map { ($_->[0] => $_->[1]) } @{ load_tabular(-file=>"$indir/$id/prokka/$id.txt", -sep=>': ') }
    };
  }
#  print STDERR Dumper(\%anno);
  
  if (1) {
    #                1      2    3    4   5     6
    my @feat = qw(contigs bases CDS rRNA tRNA tmRNA);
    my @grid = ( [ 'Isolate', @feat, 'Quality' ] );
    for my $id (@id) {
      my @row = ($id);
      for my $f (@feat) {
        push @row, $anno{$id}{$f} || '-';
      }
      # fail if #CDS >> #kbp 
      push @row, pass_fail( $row[3] > 2*$row[2]/1000 ? -1 : +1 );
      push @grid, \@row;
    }
    print $fh table_to_markdown(\@grid, 1); 
  }
}

  #...........................................................................................
  # ABR
  heading($fh, "Resistome");
  my %abr;
  for my $id (@id) {
    $abr{$id} = load_tabular(-file=>"$indir/$id/abricate.tab", -sep=>"\t", -header=>1, -key=>4); # 4 = "GENE"
  }
#  print STDERR Dumper(\%abr);

  if (1) {
#    copy("$indir/ref.fa", "$outdir/$name.ref.fa");
    my $csv_fn = "$name.resistome.csv";
#    open CSV, '>', "$outdir/$csv_fn";
    print $fh " Download: [$csv_fn]($csv_fn)\n";
    my $ABSENT = '.';
#    print $fh "\n";
    my %gene;
    map { $gene{$_}++ } (map { (keys %{$abr{$_}}) } @id);
    my @gene = sort { $a cmp $b } keys %gene;
#    print STDERR Dumper(\%gene, \@gene);
    my @grid = ( [ 'Isolate', 'Found', @gene ] ); # for HTML
    my @grid2 = ( [ @{$grid[0]} ] );              # for CSV
    
    for my $id (@id) {
      my @abr;
      my @abr2;
      for my $g (@gene) {
        my $hit = $ABSENT;
        my $hit2 = $ABSENT;
        if ($abr{$id}{$g}) {
          my @hits = @{ $abr{$id}{$g} };
          $hit = @hits == 1 && int($hits[0]->{'%COVERAGE'}) >= 95
               ? pass_fail( +1 ) 
               : pass_fail( 0, join(' + ', map { int($_->{'%COVERAGE'}).'%' } @hits) );
#          $hit = join("+", 
#            map { percent_cover( int $_->{'%COVERAGE'}, 100) } 
#              sort { $b->{'%COVERAGE'} <=> $a->{'%COVERAGE'} } @hits
#          );
          $hit2 = join("+", map { int $_->{'%COVERAGE'} } @hits);
        }
        push @abr, $hit;
        push @abr2, $hit2;
      }      
      my $found = scalar( grep { $_ ne $ABSENT } @abr );
      push @grid,  [ $id, $found, @abr ];
      push @grid2, [ $id, $found, @abr2 ];
    }
    
    # add CSS to help rotate the labels to this big table!
    my $W = scalar( @{$grid[0]} );
    for my $i (0 .. $W-1) {
      $grid[0][$i] = " <DIV CLASS='vertical'>$grid[0][$i]</DIV>";
    }
    
    print $fh table_to_markdown(\@grid, 1);
    save_tabular("$outdir/$csv_fn", \@grid2, ",");
  }

  #...........................................................................................
  # Reference Genome
  heading($fh, "Reference genome");
  my $fin = Bio::SeqIO->new(-file=>"$indir/ref.fa", -format=>'fasta');
  my $refsize;
  my @ref;
  push @ref, [ qw(Sequence Length Description) ];
  while (my $seq = $fin->next_seq) {
    my $id = $seq->id;
    $id =~ s/\|/~/g;
    push @ref, [ $id, $seq->length, ($seq->desc || 'no description') ];
    $refsize += $seq->length;
  }
#  print STDERR Dumper($r, \@ref);
  my $ncontig = scalar @ref;
  if ($ncontig < 10) {
    print  $fh table_to_markdown(\@ref, 1);
  }
  else {
    print $fh "\n_Reference sequence names not shown as too many contigs ($ncontig)\n";
  }
 
  #...........................................................................................
  # Core genome
  heading($fh, "Core genome");
  
  sub column_average {
    my($matrix, $col, $format) = @_;
    $col ||= 0;
    $format ||= "%f";
    my $nrows = $#$matrix;
    my $sum = sum( map { $matrix -> [$_] [$col] } 1 .. $nrows ); # skip header
    return sprintf $format, $sum/$nrows;
  }
  
#  my $gin = Bio::SeqIO->new(-file=>"$indir/core.nogaps.aln", -format=>'fasta');
#  my $core = $gin->next_seq;
#  printf $fh "Core genome of %d taxa is %d of %d bp (%2.f%%)\n", 
#    scalar(@id), $core->length, $refsize, $core->length*100/$refsize;
  my $core_stats = load_tabular(-file=>"$indir/core.txt", -sep=>"\t");
  $core_stats->[0][0] = 'Isolate';
  push @{$core_stats->[0]}, 'Quality';
  
  # add AVG
  push @{$core_stats}, [
    "AVERAGE",
    column_average($core_stats, 1, "%d"),
    $refsize,
    column_average($core_stats, 3, "%.2f"),
  ];

  # add QC
  for my $row (1 .. $#$core_stats) {
    my $C = $core_stats->[$row][3];
    push @{$core_stats->[$row]}, 
      pass_fail( $C < 50 ? -1 : $C < 75 ? 0 : +1 );
  }
#  unshift @$core_stats, [ 'Isolate', 'Aligned bases', 'Reference length', 'Aligned bases %' ];

  print $fh table_to_markdown($core_stats, 1);

  #...........................................................................................
  # Phylogeny
  heading($fh, "Phylogeny");
  
  my $aln = Bio::SeqIO->new(-file=>"$indir/core.aln", -format=>'fasta');
  $aln = $aln->next_seq;
  printf $fh "Core SNP alignment has %d taxa and %s bp. ", scalar(@id), $aln->length;
  
  copy("$indir/core.aln", "$outdir/$name.aln");
  copy("$indir/tree.newick", "$outdir/$name.tree");
  print $fh "Download: [$name.tree]($name.tree) | [$name.aln]($name.aln)\n";

  copy("$indir/tree.gif", "$outdir/$name.tree.gif");
  print $fh "![Core tree]($name.tree.gif)\n";

  #...........................................................................................
  # Core SNP counts
  heading($fh, "Core SNP distances");
  my $snps = load_tabular(-file=>"$indir/distances.tab", -sep=>"\t");
  print $fh table_to_markdown($snps, 1);


  #...........................................................................................
  # Core SNP density
  my $ref_fai = "$indir/ref.fa.fai";
  if (0 and -r $ref_fai) {
    heading($fh, "Core SNP density");
    my $len_of = load_tabular_as_hash($ref_fai);
    my @coord;
    open VCF, '<', "$indir/core.vcf";
    my $prevseq = '';
    my $offset = 0;
    while (<VCF>) {
      next if m/^#/;
      next unless m/^(\S+)\t(\d+)/;
      my($seq,$pos) = ($1,$2);
      if ($prevseq && $seq ne $prevseq) {
        $offset += $len_of->{$prevseq};
        $prevseq = $seq;
        print STDERR Dumper($offset);
      }
      push @coord, $offset + $pos;
    }
    @coord = sort { $a <=> $b } @coord;
    print STDERR "# ", $coord[0], "..", $coord[-1], "\n";
    open HIST, '>', 'snps.hist';
    print HIST map { "$_\n" } @coord;
    close HIST;
  }


  #...........................................................................................
  # Pan Genome
  my $roary_ss = "roary/summary_statistics.txt";
  if (-r $roary_ss) {
    heading($fh, "Pan genome");
    my $ss = load_tabular(-file=>$roary_ss, -sep=>"\t");
    unshift @$ss, [ "Ortholog class", "Definition", "Count" ];
    print $fh table_to_markdown($ss, 1);
    my $panpic = "$indir/roary/roary.png";
    if (-r $panpic) {
      copy($panpic, "$outdir/$name.pan.png");
      copy("$indir/roary/roary.png.svg", "$outdir/$name.pan.svg");
      print $fh "Download: [$name.pan.svg]($name.pan.svg)\n\n";
      print $fh "![Pan genome]($name.pan.png)\n";
    }
  }
  
  #...........................................................................................
  # Accessory Genome Tree
  my $acctree = "$indir/roary/accessory_tree.png";
  if (-r $acctree) {
    heading($fh, "Accessory Genome Tree");
    print $fh "*Note:* This tree is based on **binary** gene presence/absence of **non-singleton** accessory genes.\n\n";
    copy("$indir/roary/accessory_binary_genes.fa.newick", "$outdir/$name.acc.tree");
    print $fh "Download: [$name.acc.tree]($name.acc.tree)\n\n";
    copy($acctree, "$outdir/$name.acc.tree.png");
    print $fh "![Accessory Gene Tree]($name.acc.tree.png)\n";
  }

  #...........................................................................................
  # ParSNP
  if (-r "$indir/parsnp/$name.parsnp.png") {
    heading($fh, "ParSNP");
    
    print $fh "ParSNP aligns assembled contigs and does simplistic recombination filtering\n";
    print $fh qx(grep 'Total coverage among' $indir/parsnp/parsnpAligner.log);
    
    copy("$indir/parsnp/parsnp.tree", "$outdir/$name.parsnp.tree");
    print $fh "Download: [$name.parsnp.tree]($name.parsnp.tree)\n";

    copy("$indir/parsnp/parsnp.png", "$outdir/$name.parsnp.png");
    print $fh "![ParSNP tree]($name.parsnp.png)\n";
  }
  
  #...........................................................................................
  # Software
  heading($fh, "Software");
  my @inv = ( [ "Tool", "Version" ] );
  for my $tool (qw(nullarbor.pl mlst abricate snippy kraken samtools freebayes megahit prokka roary)) {
    # print $fh "- $tool ```", qx($tool --version 2>&1), "```\n";
    my($ver) = qx($tool --version 2>&1);
#    ($ver) = qx($tool -V 2>&1) unless $ver =~ m/$tool/i;
#    ($ver) = qx($tool 2>&1) unless $ver =~ m/$tool/i;
    chomp $ver;
    $ver =~ s/$tool\s*//i;
    $ver =~ s/version\s*//i;
    push @inv, [ "`$tool`", $ver ];
  }
  push @inv, [ "`spades`", "?" ];        # --version coming in 3.6.3
  push @inv, [ "`trimmomatic`", "?" ];   # not sure, need to file issue with them
  
  print $fh table_to_markdown(\@inv, 1);

  #...........................................................................................
  # Software
  heading($fh, "Information");
  print $fh <<"EOF";
* This software was primarily written by [Torsten Seemann](http://tseemann.github.io/)
* You can download the software from the [Nullarbor GitHub page](https://github.com/tseemann/nullarbor)
* Please report bugs to the [Nullarbor Issues page](https://github.com/tseemann/nullarbor/issues)
* If you use Nullarbor please cite: Seemann T, Kwong JC, de Silva AG, Bulach DM (2015) _Nullarbor_. **GitHub** github.com/tseemann/nullarbor
EOF
            
  
  #...........................................................................................
  # Done!
  msg("Report can be viewed in $outdir/index.md");
}

#.................................................................................

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

#.................................................................................

sub table_to_markdown {
  my($table, $header, $width) = @_;
  my $res = "\n";
  my $row_no=0;
  for my $row (@{$table}) {
    if ($width) {
      # pad to this width
      my $extra = $width - @$row;
      if ($extra > 0) {
#        print STDERR "Padding $extra columns\n";
        push @$row, (map { "." } (1..$extra));
      }
    }
    $res .= join(' | ', @$row) . "\n";
    if ($header and $row_no++ == 0) {
      $res .= join(' | ', map { '---' } @$row) . "\n";
    }
  }
  return $res."\n";
}

#.................................................................................
# EVENTUALLY!:
# -file     | filename to load
# -sep      | column separator eg. "\t" ","  (undef = auto-detect)
# -header   | 1 = yes,  0 = no,  undef = auto-detect '#' at start
# -comments | undef = none, otherwise /pattern/ to match
# -key      | undef = return list-of-lists  /\d+/ = column,  string = header column

sub load_tabular {
  my(%arg) = @_;
 
  my $me = (caller(0))[3];
  my $file = $arg{'-file'} or err("Missing -file parameter in $me");
  my $sep = $arg{'-sep'} or err("Please specify column separator in $me");

  my @hdr;
  my $key_col;
  my $res;
  my $row_no=0;

  open TABULAR, $file or err("Can't open $file in $me");
  while (<TABULAR>) {
    chomp;
    my @col = split m/$sep/;
    if ($row_no == 0 and $arg{'-header'}) {
      @hdr = @col;
      if (not defined $arg{'-key'}) {
        $key_col = undef;
      }
      elsif ($arg{'-key'} =~ m/^(\d+)$/) {
        $key_col = $1;
        $key_col < @hdr or err("Key column $key_col is beyond columns: @hdr");
      }
      else {
        my %col_of = (map { ($hdr[$_] => $_) } (0 .. $#hdr) );
        $key_col = $col_of{ $arg{'-key'} } or err("Key column $arg{-key} not in header: @hdr");
      }
    }

    if (not defined $key_col) {
      push @{$res}, [ @col ];
    }
    elsif ($row_no != 0) {
#      this code fails when there are duplicate keys!!! eg. genes in abricate.
#      $res->{ $col[$key_col] } = { map { ($hdr[$_] => $col[$_]) } 0 .. $#hdr };
      push @{ $res->{ $col[$key_col] } } , { map { ($hdr[$_] => $col[$_]) } 0 .. $#hdr };
    }
    $row_no++;
  }
  close TABULAR;
  return $res;
}

#.................................................................................
# EVENTUALLY!: use Text::CSV 

sub save_tabular {
  my($outfile, $matrix, $sep) = @_;
  $sep ||= "\t";
  open TABLE, '>', $outfile;
  for my $row (@$matrix) {
    print TABLE join($sep, @$row),"\n";
  }
  close TABLE;
}

#.................................................................................

sub load_tabular_as_hash {
  my($infile, $key_col, $val_col, $sep, $skip) = @_;
  $key_col ||= 0;
  $val_col ||= 1;
  $sep ||= "\t";
  my $result = {};
  open IN, '<', $infile;
  while (<IN>) {
    next if $skip and m/$skip/;
    chomp;
    my @row = split m/$sep/;
    $result->{ $row[ $key_col ] } = $row[ $val_col ];
  }
  return $result;
}

#.................................................................................

sub pass_fail {
    my($level, $alt_text) = @_;
    $level ||= 0;
    my $sym = '?';
    my $class = 'dunno';
    if ($level < 0) {
      $sym = "&#10008;";
      $class = 'fail';
    }
    elsif ($level > 0) {
      $sym = "&#10004;";
      $class = 'pass';
    }
    my $alt = defined($alt_text) ? " TITLE='$alt_text'" : "";
    return "<SPAN CLASS='$class'$alt>$sym</SPAN>";
}

#.................................................................................

1;

