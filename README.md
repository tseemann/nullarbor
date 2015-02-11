# Nullarbor

Pipeline to generate complete public health microbiology reports from sequenced isolates

## Etymology

The [Nullarbor](http://en.wikipedia.org/wiki/Nullarbor_Plain) is a huge treeless plain that spans the area between south-west and south-east Australia. It comes from the Latin "nullus" (no) and "arbor" (tree), or "no trees". As this software will generate a tree, there is an element of Australian irony in the name.

## Motivation

Public health microbiology labs receive batches of bacterial isolates whenever there is a suspected outbreak. In modernised labs, each of these isolates will be whole genome sequenced, typically on an Illumina or Ion Torrent instrument. Each of these WGS samples needs to quality checked for coverage, contamination and correct species. Genotyping (eg. MLST) and resistome characterisation is also required. Finally a phylogenetic tree needs to be generated to show the relationship and genomic distance between the strains. All this information is then combined with epidemiological information (metadata for each sample) to assess the situation and inform further action.

## Pipeline

### Per isolate
1. Clean reads
   * remove adaptors
   * remove low quality reads
   * trim low quality bases
2. Species identification
   * k-mer analysis against known genome database (Kraken)
   * random sampling of reads against known genome (BLAST)
3. De novo assembly
   * Fast, confident but more contigs (MEGA-HIT)
   * Intermediate quality (Velvet)
   * Slow, high quality (Spades)
4. Annotation
   * Genome annotation (Prokka)
5. MLST
   * From assembly (mlst)
   * From reads (SRST2)
6. Resistome
   * From assembly (abricate)
   * From reads (SRST2)

### Per isolate set
1. Core genome SNPs
   * From reads (Wombac)
   * From contigs (ParSNP)
2. Draw tree
   * Neighbour joining (FastTree)
   * SNP distance matrix (afa-pairwise)
3. Report
   * Table of isolates, yield, coverage, species, MLST

### Features
* Identify outliers
* Automatically choose appropriate reference genome
* Include some sparse closed references in tree
