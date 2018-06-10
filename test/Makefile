
ASSEMBLER=skesa
REF=ref.gbk
OUTDIR=nullarbor
LEN=150
NUMSAMPLES=5
SAMPLES=$(shell seq -f "EF%03.0f" 1 $(NUMSAMPLES))

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
	wgsim -e 0.04 -h -N 30000 -1 $(LEN) -2 $(LEN) $< $@ $(@D)/R2.fq > $(@D)/wgsim.tab
	gzip $(@D)/R?.fq
	echo -e $(@D)"\t"$(PWD)/$(@D)/R1.fq.gz"\t"$(PWD)/$(@D)/R2.fq.gz > $(@D)/reads.tab

input.tab: $(addsuffix /R1.fq.gz,$(SAMPLES))
	cat $(addsuffix /reads.tab,$(dir $^*)) > $@

%.fasta: %.gbk
	seqret -auto -filter -osformat2 fasta < $< > $@

clean:
	rm -fr $(OUTDIR) $(SAMPLES) input.tab ref.fasta
