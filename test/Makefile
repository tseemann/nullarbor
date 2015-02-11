
DATA=data
TESTDIR=./t

setup:
	../bin/nullarbor.pl --outdir $(TESTDIR) --ref $(DATA)/ref.fa --input $(DATA)/data.tab  --force --mlst saureus

run:
	make -C $(TESTDIR)
	        
all: setup run doc

test: all
	make -C $(TESTDIR) parsnp

testdata:
	./make_test_data.sh
	
clean:
	rm -fr $(TESTDIR)

doc:
	../bin/nullarbor.pl --report --indir t --outdir t/report	
	pandoc --from markdown_github --to html t/report/index.md > t/report/index.html
	cat t/report/index.html
	cat t/report/index.md
	rm -fr $(HOME)/public_html/tmp/mdu
	cp -rf t/report $(HOME)/public_html/tmp/mdu

	
	