# Nullarbor

Pipeline to generate complete public health microbiology reports from sequenced isolates

:warning: This documents the previous Nullarbor 1.x version. Version 2.x is [here](README.md)

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

## Example reports

Feel free to browse some [example reports](http://tseemann.github.io/nullarbor/).

## Pipeline

### Limitations

Nullarbor currently only supports Illumina paired-end sequencing data;
single end reads, from either Illumina or Ion Torrent are not supported.
All jobs are run on a single compute node; there is no support yet for
distributing the work across a high performance cluster.

### Per isolate

1. Clean reads
   * remove adaptors, low quality bases and reads (Trimmomatic)
2. Species identification
   * k-mer analysis against known genome database (Kraken)
3. _De novo_ assembly
   * Fast mostly-good-enough assembly (MEGA-HIT)
   * More accurate, but slower assembly (SPAdes) using `--accurate`
4. Annotation
   * Genome annotation (Prokka)
5. MLST
   * From assembly w/ automatic scheme detection (mlst)
6. Resistome
   * From assembly (abricate)
7. Variants
   * From reads relative to reference (Snippy)

### Per isolate set

1. Core genome SNPs
   * From reads (Snippy-core)
2. Infer core SNP phylogeny 
   * Maximum likelihood (FastTree)
   * SNP distance matrix (afa-pairwise)
3. Pan genome
   * From annotated contigs (Roary)
4. Report
   * Table of isolates, yield, coverage, species, MLST (HTML + Plotly.JS + DataTables)

## Installation

### Warning

Installing Nullarbor is not easy. It is a complex pipeline, and depends on lots of external
tools and databases. If you have access to cloud or virtual machines you may wish to consider
using the [Genomics Virtual Lab image](http://genome.edu.au/) or the 
[Ubuntu 14.04 installer](https://gist.github.com/stephenturner/005d4e4e322b8cf5b991d1d357527859)
by @stephenturner.

### Local installation

Please first install the [Linuxbrew](https://github.com/Homebrew/linuxbrew) package manner, then:

    brew tap homebrew/science
    brew tap tseemann/bioinformatics-linux
    brew install nullarbor --HEAD

You need to install a [Kraken](https://ccb.jhu.edu/software/kraken/) database.

    wget https://ccb.jhu.edu/software/kraken/dl/minikraken.tgz
    
Choose a folder (say `$HOME`) to put it in, you need ~4 GB free:

    tar -C $HOME -zxvf minikraken.tgz

Then add the following to your `$HOME/.bashrc` so Nullarbor can use it:

    export KRAKEN_DB_PATH=$HOME/minikraken_20141208

You should be good to go now. When you first run Nullarbor it will let you
know of any missing dependencies or databases.

## Usage

### Create a 'samples' file (TAB)

This is a file, one line per isolate, with 3 tab separated columns: ID, R1, R2.

    Isolate1	/data/reads/Isolate1_R1.fq.gz	/data/reads/Isolate2_R1.fq.gz
    Isolate2	/data/reads/Isolate2_R1.fq      /data/reads/Isolate2_R2.fq
    Isolate3	/data/old/s_3_1_sequence.txt	/data/old/s_3_2_sequence.txt
    Isolate3b	/data/reads/Isolate3b_R1.fastq	/data/reads/Isolate3b_R2.fastq

### Choose a reference genome (FASTA, GENBANK)

This is just a regular FASTA or GENBANK file. Try and choose a reference phylogenomically similar to your isolates.    
If you use a GENBANK or EMBL file the annotations will be used to annotate SNPs by Snippy.

### Generate the run folder

This command will create a new folder with a `Makefile` in it:

    nullarbor.pl --name PROJNAME --mlst saureus --ref US300.fna --input samples.tab --outdir OUTDIR

This will check that everything is okay. One of the last lines it prints is the command you need to run
to actually perform the analysis _e.g._

    Run the pipeline with: nice make -j 4 -C OUTDIR

So you can just cut and paste that:

    nice make -j 4 -C OUTDIR

The `-C` option just means to change into the `/home/maria/listeria/nullarbor` folder first, so you could 
do this instead:

    cd OUTDIR
    make -j 4

### View the report

    firefox OUTDIR/report/index.html

Here are some [example reports](http://tseemann.github.io/nullarbor/).

### See some options

Once set up, a Nullarbor folder can be used in a few different ways. 
See what's available with this command:

    make help

## Etymology

The [Nullarbor](http://en.wikipedia.org/wiki/Nullarbor_Plain) 
is a huge treeless plain that spans the area between south-west and
south-east Australia.  It comes from the Latin "nullus" (no) and "arbor"
(tree), or "no trees".  As this software will generate a tree, there is an
element of Australian irony in the name.

## Issues

Submit problems to the [Issues Page](https://github.com/tseemann/nullarbor/issues)

## License

[GPL 2.0](https://raw.githubusercontent.com/tseemann/nullarbor/master/LICENSE)

## Citation

Seemann T, Goncalves da Silva A, Bulach DM, Schultz MB, Kwong JC, Howden BP.
*Nullarbor* 
**Github** https://github.com/tseemann/nullarbor
