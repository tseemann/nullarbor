[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) ![Don't judge me](https://img.shields.io/badge/Language-Perl_5-steelblue.svg)

# Nullarbor

Pipeline to generate complete public health microbiology reports from sequenced isolates

:warning: This documents the current Nullarbor 2.x version; previous 1.x is [here](README.V1.md)

## Motivation

Public health microbiology labs receive batches of bacterial isolates
whenever there is a suspected outbreak.In modernised labs, each of these
isolates will be whole genome sequenced, typically on an Illumina or Ion
Torrent instrument. Each of these WGS samples needs to quality checked for
coverage, contamination and correct species. Genotyping (eg. MLST) and
resistome characterisation is also required. Finally a phylogenetic tree
needs to be generated to show the relationship and genomic distance between
the strains. All this information is then combined with epidemiological
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
   * k-mer analysis against known genome database (Kraken, Kraken2, Centrifuge)
3. _De novo_ assembly
   * User can select (SKESA, SPAdes, Megahit, [shovill](https://github.com/tseemann/shovill), Velvet)
4. Annotation
   * Add features to assembly [Prokka](https://github.com/tseemann/prokka))
5. MLST
   * From assembly w/ automatic scheme detection ([mlst](https://github.com/tseemann/mlst) + _PubMLST_)
6. Resistome
   * From assembly ([abricate](https://github.com/tseemann/abricate) + _Resfinder_)
7. Virulome
   * From assembly ([abricate](https://github.com/tseemann/abricate) + _VFDB_)
8. Variants
   * From reads aligned to reference ([snippy](https://github.com/tseemann/snippy))

### Per isolate set

1. Core genome SNPs
   * From reads ([snippy-core](https://github.com/tseemann/snippy))
2. Infer core SNP phylogeny 
   * Maximum-likelihood GTR+G4 model ([IQTree](https://www.iqtree.org), [FastTree](http://www.microbesonline.org/fasttree/))
   * SNP distance matrix ([snp-dists](https://github.com/tseemann/snp-dists))
3. Pan genome
   * From annotated contigs ([Roary](https://sanger-pathogens.github.io/Roary/))
4. Report
   * Summary isolate information (HTML + Plotly.JS + DataTables + PhyloCanvas)
   * More detailed per isolate pages (COMING SOON)

## Installation

### Software

#### Github
This is the hardest way to instal Nullarbor, but is currently the only way for version 2:

    cd $HOME
    git clone https://github.com/tseemann/nullarbor.git
    
    # keep running this command and installing stuff until it says everything is correct
    ./nullarbor/bin/nullarbor.pl --check
    
    # For Perl modules (eg. YAML::Tiny), use one of the following methods
    apt-get install yaml-tiny-perl  # ubuntu/debian
    yum install perl-YAML-Tiny      # centos/redhat
    cpan YAML::Tiny
    cpanm YAML::Tiny

#### Homebrew
Install [Homebrew](http://brew.sh/) (macOS) or [LinuxBrew](http://linuxbrew.sh/) (Linux).

    brew untap homebrew/science
    brew untap tseemann/bioinformatics-linux
    brew install brewsci/bio/nullarbor # COMING SOON!

#### Conda
Install [Conda](https://conda.io/docs/) or [Miniconda](https://conda.io/miniconda.html):

    conda install -c bioconda -c conda-forge nullarbor  # COMING SOON!

#### Containers
Once the `bioconda` package is working, Docker and Singularity containers will follow.

### Databases

#### Kraken

You need to install a [Kraken](https://ccb.jhu.edu/software/kraken/) database (~4 GB).

    wget https://ccb.jhu.edu/software/kraken/dl/minikraken_20171019_4GB.tgz
    tar -C $HOME -zxvf minikraken_20171019_4GB.tgz

#### Centrifuge
    
Install a [Centrifuge](http://www.ccb.jhu.edu/software/centrifuge/) database (~8 GB):

    wget ftp://ftp.ccb.jhu.edu/pub/infphilo/centrifuge/data/p_compressed+h+v.tar.gz
    mkdir $HOME/centrifuge-db
    tar -C $HOME/centrifuge-db -zxvf p_compressed+h+v.tar.gz

#### Set global database locations

Then add the following to your `$HOME/.bashrc` so Nullarbor can find the databases:

    export KRAKEN_DEFAULT_DB=$HOME/minikraken_20171019_4GB
    export CENTRIFUGE_DEFAULT_DB=$HOME/centrifuge-db/p_compressed+h+v

You should be good to go now. When you first run Nullarbor it will let you
know of any missing dependencies or databases.

## Usage

### Check dependencies

Nullarbor does a self-check of all binaries, Perl modules and databases:

    nullarbor.pl --check

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

## Advanced usage

### Quick preview mode

You should not do a full run the first time, because it will probably
contain outliers and QC failures. To build a quick "rough" tree:
```
make preview
```
This will create a mini-report in the same `report/` folder.
Use this to identify outliers and then comment them out (or delete)
them from the `--input` file. Then type the following to regenerate
the report for a second round of inspection:
```
make again
make preview
```
When you are happy with the result, proceed with the full analysis:
```
make again
make
```

### Prefilling data

Often you want to perform multiple analyses where some of the isolates
have been used in previous Nullarbor runs. It is wasteful to recompute
results you already have.  The `--prefill` option allows you to "copy"
existing result files into a new Nullarbor folder before commencing
the run.

To set it up, add a `prefill` section to `nullarbor.conf` as follows:
```
# nullarbor.conf
prefill:
        contigs.fa: /home/seq/MDU/QC/{ID}/contigs.fa
```
The `{ID}` will replaced for each isolate ID in your `--input` TAB file
and the `contigs.fa` copied from the source path specified. This will
prevent Nullarbor having to re-assemble the reads.

### Using different components

Nullarbor 2.x has a plugin system for _assembly_ and _tree building_.
These can be changed using the `--assembler` and `--treebuilder` options.

Read trimming is off by default, because most sequences are now
provided pre-trimmed, and retrimming occupies much disk space.
To trim Illumina adaptors, use the `--trim` option.

### Removing isolates from an existing run

After examining the report from your initial analysis, it is common
to observe some outliers, or bad data. In this case, you want to 
remove those isolates from the analysis, but want to minimize the
amount of recomputation needed.

Just go to the _original_ `--input TAB` file and either (1) remove
the offending lines; or (2) just add a `#` symbol to "comment out"
the line and it will be ignored by Nullarbor.

Then go back into the Nullarbor folder and type `make again`
and it should make a new report.  Assemblies and SNPs won't be
redone, but the tree-builder and pan-genome components will
need to run again.

### Adding isolates to an existing run

As per "Removing isolates" above, you can also add in more isolates
to your original `--input TAB` file when you want to expand the analysis.
Then just type `make again` and it should only recalculate
things it needs to, saving a lot of computation.

### Immediate start

If you don't want to cut and paste the `make ....` instructions to 
start the analysis, just add the `--run` option to your `nullarbor.pl` command.

## Influential environmental variables

* `NULLARBOR_CONF` - default `--conf`, the path to `nullarbor.conf`
* `NULLARBOR_ASSEMBLER` - default `--assembler` tool
* `NULLARBOR_TREEBUILDER` - default `--treebuilder` tool
* `NULLARBOR_TAXONER` - default `--taxoner` tool

## Dependencies

Nullarbor has *many* dependencies, so you are best off using a package
manager to install it. Type `nullarbor.pl --check` to see what you need.

__Perl:__ Bio::Perl Time::Piece List::Util Path::Tiny YAML::Tiny
Moo SVG Text::CSV List::MoreUtils IO::File

__Tools:__ seqtk trimmomatic prokka roary mlst abricate seqret skesa
megahit spades shovill snippy snp-dists newick-utils iqtree fasttree
quicktree kraken kraken2 centrifuge

__Databases:__ minikraken centrifuge-bacvirhum

Note that these are only the *immediate* dependencies and that the
tools listed above will depend on various other tools, Perl modules,
and Python modules.

## Etymology

The [Nullarbor](http://en.wikipedia.org/wiki/Nullarbor_Plain) 
is a huge treeless plain that spans the area between south-west and
south-east Australia. It comes from the Latin "nullus" (no) and "arbor"
(tree), or "no trees". As this software will generate a tree, there is an
element of Australian irony in the name.

## Issues

Submit problems to the [Issues Page](https://github.com/tseemann/nullarbor/issues)

## License

[GPL 2.0](https://raw.githubusercontent.com/tseemann/nullarbor/master/LICENSE)

## Citation

Seemann T, Goncalves da Silva A, Bulach DM, Schultz MB, Kwong JC, Howden BP.
*Nullarbor* 
**Github** https://github.com/tseemann/nullarbor
