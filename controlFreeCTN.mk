# Use ExomeCNV to detect copy number variants and LOH
# vim: set ft=make :

include ~/share/modules/Makefile.inc

READ_LENGTH ?= 75

LOGDIR = log/control_freec.$(NOW)
FREEC = $(HOME)/share/usr/bin/freec
FREEC_THREADS = 4
# mem is per thread
FREEC_MEM = 4G
FREEC_HMEM = 6G

MAKE_GRAPH = $(HOME)/share/scripts/makeGraph.R

FREEC_WINDOW_SIZE = 50000

GC_CONTENT_NORM = 0

VPATH ?= bam

ifeq ($(EXOME),true)
FREEC_TARGET_CONFIG =[target]\n\
captureRegions=$(EXOME_BED)
NOISY_DATA = true
PRINT_NA = false
else
FREEC_TARGET_CONFIG = 
NOISY_DATA = false
PRINT_NA = true
endif

#usage $(call FREEC_CONFIG,tumor-bam,normal-bam,output-dir)
define FREEC_CONFIG
[general]\n\
chrFiles=$(FREEC_REF)\n\
chrLenFile=$(CHR_LEN)\n\
maxThreads=$(FREEC_THREADS)\n\
samtools=$(SAMTOOLS)\n\
outputDir=$3\n\
noisyData=$(NOISY_DATA)\n\
ploidy=2\n\
coefficientOfVariation=0.05\n\
window=$(FREEC_WINDOW_SIZE)\n\
gemMappabilityFile=$(GEM_MAP_FILE)\n\
printNA=$(PRINT_NA)\n\
forceGCcontentNormalization=$(GC_CONTENT_NORM)\n\
[sample]\n\
mateFile=$1\n\
inputFormat=BAM\n\
mateOrientation=FR\n\
[control]\n\
mateFile=$2\n\
inputFormat=BAM\n\
mateOrientation=FR\n\
[BAF]\n\
shiftInQuality=33\n\
$(FREEC_TARGET_CONFIG)
endef

.SECONDARY:
.DELETE_ON_ERROR:
.PHONY: all cnv config

all : cnv config
cnv : $(foreach tumor,$(TUMOR_SAMPLES),freec/$(tumor).bam_ratio.txt.png)
config : $(foreach tumor,$(TUMOR_SAMPLES),freec/$(tumor)_$(normal_lookup.$(tumor)).config.txt)

#$(call config-tumor-normal,tumor,normal)
define freec-config-tumor-normal
freec/$1_$2.config.txt : $1.bam $2.bam
	$$(INIT) echo -e "$$(call FREEC_CONFIG,$$<,$$(word 2,$$^),$$(@D))" | sed 's/ //' >  $$@
endef
$(foreach tumor,$(TUMOR_SAMPLES),$(eval $(call freec-config-tumor-normal,$(tumor),$(normal_lookup.$(tumor)))))

define freec-tumor-normal
freec/$1.bam_ratio.txt : freec/$1_$2.config.txt
	$$(call LSCRIPT_PARALLEL_MEM,$$(FREEC_THREADS),$$(FREEC_MEM),$$(FREEC_HMEM),"$$(FREEC) -conf $$< &> $$(LOG)")
endef
$(foreach tumor,$(TUMOR_SAMPLES),$(eval $(call freec-tumor-normal,$(tumor),$(normal_lookup.$(tumor)))))

freec/%.bam_ratio.txt.png : freec/%.bam_ratio.txt
	$(call LSCRIPT_MEM,2G,4G,"cat $(MAKE_GRAPH) | $(R) --slave --args 2 $< &> $(LOG)")
