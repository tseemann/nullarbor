package Nullarbor::Report;
use Moo;

use Nullarbor::Logger qw(msg err);
use Data::Dumper;
use File::Copy;
use Bio::SeqIO;
use List::Util qw(sum);

#.................................................................................

sub generate {
  my($self, $indir, $outdir, $name) = @_;

  $name ||= $outdir;

  msg("Generating $name report in: $outdir");
  open my $fh, '>', "$outdir/index.md";
  copy("$FindBin::Bin/../conf/nullarbor.css", "$outdir/");  

  #...........................................................................................
  # Load isolate list

  my $isolates_fname = 'isolates.txt';
  open ISOLATES, '<', $isolates_fname or err("Can not open $indir/$isolates_fname");
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
    [ "Report", "Isolates", "Author", "Date" ],
    [ $name, scalar(@id), $user, $date ],
  ];
  print $fh table_to_markdown($meta_data, 1);

#  print $fh "__Report:__ $name\n";
#  print $fh "__Date:__ $date\n";
#  print $fh "__Author:__ $user\n";
#  printf $fh "__Isolates:__ %d\n", scalar(@id);

  #...........................................................................................
  # MLST
  
  my $mlst = load_tabular(-file=>"$indir/mlst.tab", -sep=>"\t", -header=>1);
#  print STDERR Dumper($mlst);
  
  for my $row (@$mlst) {
    $row->[0] =~ s{/contigs.fa}{};
    $row->[0] =~ s/ref.fa/Reference/;
    # move ST column to end to match MDU LIMS
    my($ST) = splice @$row, 2, 1;
    my $missing = sum( map { $row->[$_] eq '-' ? 1 : 0 } (1 .. $#$row) );
    push @$row, "**${ST}**";
    push @$row, pass_fail( $missing==0 && $ST ne '-' ? +1 : $missing <= 1 ? 0 : -1 );
  }
  $mlst->[0][0] = 'Isolate';
  $mlst->[0][-1] = 'Quality';

  print $fh "##MLST\n";
  save_tabular("$outdir/$name.mlst.csv", $mlst);
  print $fh "Download: [$name.mlst.csv]($name.mlst.csv)\n";
  print $fh table_to_markdown($mlst, 1);
    
  #...........................................................................................
  # Yields


  #for my $stage ('dirty', 'clean') {
  for my $stage ('clean') {
    print $fh "##Sequence data\n";
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
  print $fh "##Sequence identification\n";
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
  # Assembly
  print $fh "##Assembly\n";
  my $ass = load_tabular(-file=>"$indir/denovo.tab", -sep=>"\t", -header=>1);
#  print STDERR Dumper($ass);
  $ass->[0][0] = 'Isolate';
  $ass->[0][1] = 'Contigs';
  map { $_->[0] =~ s{/contigs.fa}{} } @$ass;
  # extract insert size from BWA output in Snippy folder
  push @{$ass->[0]}, "Insert size (25,50,75)%";
  push @{$ass->[0]}, "Quality";
  for my $row (1 .. @$ass-1) {
    my $id = $ass->[$row][0];
    push @{ $ass->[$row] }, extract_insert_size("$indir/$id/$id/snps.log");
    push @{$ass->[$row] }, pass_fail( $ass->[$row][1] > 1000 ? -1 : +1 );
  }
  print $fh table_to_markdown($ass,1);

  #...........................................................................................
  # Annotation
  print $fh "##Annotation\n";
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

  #...........................................................................................
  # ABR
  print $fh "##Resistome\n";
  my %abr;
  for my $id (@id) {
    $abr{$id} = load_tabular(-file=>"$indir/$id/abricate.tab", -sep=>"\t",-header=>1, -key=>4);
  }
#  print STDERR Dumper(\%abr);
  my @abr;
  push @abr, [ qw(Isolate Genes) ];
  for my $id (@id) {
    my @x = sort keys %{$abr{$id}};
    @x = 'n/a' if @x==0;
    push @abr, [ $id, join( ',', @x) ];
  }
#  print $fh table_to_markdown(\@abr, 1);

  sub percent_cover {
    my($pc, $threshold) = @_;
    $threshold ||= 50;
    if ($pc >= $threshold) { 
      return pass_fail(+1);
    }
    return "$pc%";
  }

  if (1) {
    print $fh "\n";
    my %gene;
    map { $gene{$_}++ } (map { (keys %{$abr{$_}}) } @id);
    my @gene = sort { $a cmp $b } keys %gene;
#    print STDERR Dumper(\%gene);
    my @grid;
#    my @vertgene = map { '__'.join(' ', split m//, $_).'__' } @gene;
    push @grid, [ 'Isolate', 'Found', @gene ];
    for my $id (@id) {
      my @abr = map { exists $abr{$id}{$_} ? percent_cover( int($abr{$id}{$_}{'%COVERAGE'}), 100) : '.' } @gene;
      my $found = scalar( grep { $_ ne '.' } @abr );
      push @grid, [ $id, $found, @abr ];
    }
    print $fh table_to_markdown(\@grid, 1);
  }

  #...........................................................................................
  # Reference Genome
  print $fh "##Reference genome\n";
  my $fin = Bio::SeqIO->new(-file=>"$indir/ref.fa", -format=>'fasta');
  my $refsize;
  my @ref;
  push @ref, [ qw(Sequence Length Description) ];
  while (my $seq = $fin->next_seq) {
    my $id = $seq->id;
    $id =~ s/\W+/_/g;
    push @ref, [ $id, $seq->length, '_'.($seq->desc || 'no description').'_' ];
    $refsize += $seq->length;
  }
#  print STDERR Dumper($r, \@ref);
  copy("$indir/ref.fa", "$outdir/$name.ref.fa");
  printf $fh "Reference contains %d sequences totalling %.2f Mbp. ", @ref-1, $refsize/1E6;
  print  $fh " Download: [$name.ref.fa]($name.ref.fa)\n";
  if (@ref < 10) {
    print  $fh table_to_markdown(\@ref, 1);
  }
  else {
    print $fh "\n_Contig table not shown due to number of contigs; likely draft genome._\n";
  }
 
  #...........................................................................................
  # Core genome
  print $fh "##Core genome\n";
  
  my $gin = Bio::SeqIO->new(-file=>"$indir/core.nogaps.aln", -format=>'fasta');
  my $core = $gin->next_seq;
  printf $fh "Core genome of %d taxa is %d of %d bp (%2.f%%)\n", 
    scalar(@id), $core->length, $refsize, $core->length*100/$refsize;
  my $core_stats = load_tabular(-file=>"$indir/core.txt", -sep=>"\t");
  $core_stats->[0][0] = 'Isolate';
  # add QC
  push @{$core_stats->[0]}, 'Quality';
  for my $row (1 .. @id) {
    my $C = $core_stats->[$row][3];
    push @{$core_stats->[$row]}, 
      pass_fail( $C < 50 ? -1 : $C < 75 ? 0 : +1 );
  }
#  unshift @$core_stats, [ 'Isolate', 'Aligned bases', 'Reference length', 'Aligned bases %' ];
  print $fh table_to_markdown($core_stats, 1);

  #...........................................................................................
  # Phylogeny
  print $fh "##Phylogeny\n";
  
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
  print $fh "##Core SNP distances\n";
  my $snps = load_tabular(-file=>"$indir/distances.tab", -sep=>"\t");
  print $fh table_to_markdown($snps, 1);

  #...........................................................................................
  # Core SNP density
  my $ref_fai = "$indir/ref.fa.fai";
  if (0 and -r $ref_fai) {
    print $fh "##Core SNP density\n";
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
    print $fh "##Pan genome\n";
    my $ss = load_tabular(-file=>$roary_ss, -sep=>":");
    unshift @$ss, [ "Ortholog class", "Count" ];
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
  # Software
  print $fh "##Software\n";
  my @inv = ( [ "Tool", "Version" ] );
  for my $tool (qw(nullarbor.pl mlst abricate snippy kraken samtools freebayes megahit prokka roary)) {
    # print $fh "- $tool ```", qx($tool --version 2>&1), "```\n";
    my($ver) = qx($tool --version 2>&1);
    chomp $ver;
    $ver =~ s/$tool\s*//i;
    $ver =~ s/version\s*//i;
    push @inv, [ "`$tool`", $ver ];
  }
  print $fh table_to_markdown(\@inv, 1);

  #...........................................................................................
  # Software
  print $fh <<"EOF";
##Information
* This software was primarily written by [Torsten Seemann](http://tseemann.github.io/)
* You can download the software from the [Nullarbor GitHub page](https://github.com/tseemann/nullarbor)
* Please report bugs to the [Nullarbor Issues page](https://github.com/tseemann/nullarbor/issues)
* If you this Nullarbor, please cite: Seemann T, Bulach DM, Kwong JK (2015) _Nullarbor_. **GitHub** github.com/tseemann/nullarbor
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
  my($table, $header) = @_;
  my $res = "\n";
  my $row_no=0;
  for my $row (@{$table}) {
    $res .= join(' | ', @$row)."\n";
    if ($header and $row_no++ == 0) {
      $res .= join(' | ', map { '---' } @$row)."\n";
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
      $res->{ $col[$key_col] } = { map { ($hdr[$_] => $col[$_]) } 0 .. $#hdr };
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
    my($level) = @_;
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
    return "<SPAN CLASS='$class'>$sym</SPAN>";
}

#.................................................................................

1;

