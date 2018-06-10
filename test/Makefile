
ASSEMBLER=skesa
REF=ref.gbk
OUTDIR=nullarbor
LEN=150
NUMSAMPLES=4
SAMN=EF
SAMPLES=$(shell seq -f "$(SAMN)%03.0f" 1 $(NUMSAMPLES))

.PHONY: clean

all: clean $(OUTDIR)/report/index.html

$(OUTDIR)/report/index.html: $(REF) input.tab 
	../bin/nullarbor.pl \
		--ref $(word 1,$^) \
		--input $(word 2,$^) \
		--assembler $(ASSEMBLER) \
		--outdir $(OUTDIR) \
		--name $(OUTDIR) \
		--force --run

%/R1.fq.gz : ref.fasta
	mkdir -p $(@D)
	dwgsim $< $(@D)/read -C 30 -1 150 -2 150 -H -r 0.001 -P $(@D)
	gzip -c $(@D)/read.bwa.read1.fastq > $@
	gzip -c $(@D)/read.bwa.read2.fastq > $(@D)/R2.fq.gz
	echo -e $(@D)"\t"$(PWD)/$(@D)/R1.fq.gz"\t"$(PWD)/$(@D)/R2.fq.gz > $(@D)/reads.tab

input.tab: $(addsuffix /R1.fq.gz,$(SAMPLES))
	cat $(addsuffix /reads.tab,$(dir $^*)) > $@

%.fasta: %.gbk
	seqret -auto -filter -osformat2 fasta < $< > $@

clean:
	rm -fr $(OUTDIR) $(SAMPLES) input.tab ref.fasta *~

