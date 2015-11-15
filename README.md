# Nullarbor

Pipeline to generate complete public health microbiology reports from sequenced isolates

By Torsten Seemann (@torstenseemann)

## Motivation

Public health microbiology labs receive batches of bacterial isolates
whenever there is a suspected outbreak.  In modernised labs, each of these
isolates will be whole genome sequenced, typically on an Illumina or Ion
Torrent instrument.  Each of these WGS samples needs to quality checked for
coverage, contamination and correct species.  Genotyping (eg.  MLST) and
resistome characterisation is also required.  Finally a phylogenetic tree
needs to be generated to show the relationship and genomic distance between
the strains.  All this information is then combined with epidemiological
information (metadata for each sample) to assess the situation and inform
further action.

## Pipeline

### Per isolate

1. Clean reads
   * remove adaptors, low quality bases and reads (Skewer)
2. Species identification
   * k-mer analysis against known genome database (Kraken)
3. De novo assembly
   * Fast, confident but more contigs (MEGA-HIT)
4. Annotation
   * Genome annotation (Prokka)
5. MLST
   * From assembly (mlst)
6. Resistome
   * From assembly (abricate)
7. Variants
   * From reads relative to reference (Snippy)

### Per isolate set

1. Core genome SNPs
   * From reads (Snippy)
   * From contigs (ParSNP)
2. Draw tree
   * Maximum likelihood (FastTree)
   * SNP distance matrix (afa-pairwise)
3. Report
   * Table of isolates, yield, coverage, species, MLST (Markdown, HTML)

### Planned features

* Identify outliers 
* Automatically choose appropriate reference genome
* Automatically choose MLST scheme
* Include some sparse closed references in tree
* Pre-overlap reads with PEAR to improve assembly

## Installation

Please first install the [Linuxbrew](https://github.com/Homebrew/linuxbrew) package manner, then:

    brew tap homebrew/science
    brew tap chapmanb/cbl
    brew tap tseemann/bioinformatics-linux
    brew install nullarbor

## Usage

### Create a 'samples' file (TAB)

This is a file, one line per isolate, with 3 tab separated columns: ID, R1, R2.

    Isolate1	/data/reads/Isolate1_R1.fq.gz	/data/reads/Isolate2_R1.fq.gz
    Isolate2	/data/reads/Isolate2_R1.fq	/data/reads/Isolate2_R2.fq
    Isolate3	/data/old/s_3_1_sequence.txt	/data/old/s_3_2_sequence.txt
    Isolate3b	/data/reads/Isolate3b_R1.fastq	/data/reads/Isolate3b_R2.fastq

### Choose a reference genome (FASTA, GENBANK)

This is just a regular FASTA file. Try and choose a reference phylogenomically similar to your isolates.    
If you use a GENBANK or EMBL file the annotations will be used to annotate SNPs by Snippy.

### Generate the run folder

This command will create a new folder with a Makefile in it:

    nullarbor.pl --name PROJNAME --mlst saureus --ref US300.fna --input samples.tab --outdir OUTDIR

### See some options

Once set up, a Nullarbor folder can be used in a few different ways. 
See what's available with this command:

    make help

### Run

To actually run the analysis:

    cd OUTDIR
    make 

Or if you want to run parallel jobs:

    make -C OUTDIR -j 8

### View the report

    firefox OUTDIR/report/index.html

An example report will be made available soon.

## Etymology

The [Nullarbor](http://en.wikipedia.org/wiki/Nullarbor_Plain) 
is a huge treeless plain that spans the area between south-west and
south-east Australia.  It comes from the Latin "nullus" (no) and "arbor"
(tree), or "no trees".  As this software will generate a tree, there is an
element of Australian irony in the name.

## Issues

Submit problems to the [Issues Page](https://github.com/tseemann/nullarbor/issues)

## Citation

Nullarbor is not published yet. Please use this URL: https://github.com/tseemann/nullarbor

## Example report

FIXME
