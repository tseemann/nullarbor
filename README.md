# Nullarbor

Pipeline to generate complete public health microbiology reports from sequenced isolates

## Etymology

The [Nullarbor](http://en.wikipedia.org/wiki/Nullarbor_Plain) is a huge treeless plain that spans the area between south-west and south-east Australia. It comes from the Latin "nullus" (no) and "arbor" (tree), or "no trees". As this software will generate a tree, there is an element of Australian irony in the name.

## Motivation

Public health microbiology labs received batches of bacterial isolates whenever there is a suspected outbreak. In modernised labs, each of these isolates will be whole genome sequenced, typically on an Illumina or Ion Torrent instrument. Each of these WGS samples needs to quality checked for coverage, contamination and correct species. Genotyping (eg. MLST) and resistome characterisation is also required. Finally a phylogenetic tree needs to be generated to show the relationship and genomic distance between the strains. All this information is then combined with epidemiological information (metadata for each sample) to assess the situation and inform further action.

## Pipeline


