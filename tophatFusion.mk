include ~/share/modules/Makefile.inc
include ~/share/modules/gatk.inc

TOPHAT := $(HOME)/share/usr/bin/tophat2
TOPHAT_OPTS := --no-coverage-search --fusion-ignore-chromosomes MT --fusion-search --keep-fasta-order

ifeq ($(PHRED64),true)
	TOPHAT_OPTS += --solexa1.3-quals
endif

.SECONDARY:
.DELETEONERROR:
.PHONY: all

all : $(foreach sample,$(SAMPLES),tophat/$(sample)/fusions.out)

tophat/%/fusions.out : fastq/%.1.fastq.gz.md5 fastq/%.2.fastq.gz.md5 tophat/ins_size/%.insert_size.txt
	DIST_OPTS=`perl -e '$$text = do {local $$/ ; <>}; $$text =~ m/Read length: mean (\d+).*\nRead span: mean (\d+).*STD=(\d+)/; print "--mate-inner-dist " . ($$2 - $$1 * 2) . " --mate-std-dev $$3";' $(word 3,$^)`; \
	$(call LSCRIPT_PARALLEL_MEM,4,6G,10G,"$(CHECK_MD5) $(TOPHAT) $(TOPHAT_OPTS) -p 4 $$DIST_OPTS -o $(@D) $(BOWTIE_REF) $(<M) $(word 2,$(^M))")

tophat/ins_size/%.insert_size.txt : bam/%.bam
	$(call LSCRIPT,"$(SAMTOOLS) view $< | $(GET_INSERT_SIZE) - > $@")

tophat/fusions/%.fusions.ft.txt : tophat/%/fusions.out
	awk '$5 > 100 { print }' $< 
