# Start by exporting the shared drmaa libaries to the LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/sw/apps/build/slurm-drmaa/1.0.6/lib/:$LD_LIBRARY_PATH

#---------------------------------------------
# Check if we are running on uppmax or locally, and set the jobrunners and path accordingly
#---------------------------------------------
if [ -f "/sw/apps/build/slurm-drmaa/lib/libdrmaa.so" ];
then
	JOB_RUNNER=" Drmaa"
	JOB_NATIVE_ARGS="-A ${PROJECT_ID} -p node -N 1 ${QOS}"
	PATH_TO_BWA="/sw/apps/bioinfo/bwa/0.6.2/kalkyl/bwa"
	PATH_TO_SAMTOOLS="/sw/apps/bioinfo/samtools/0.1.12-10/samtools"	
	PATH_TO_TOPHAT="/sw/apps/bioinfo/tophat/2.0.4/kalkyl/bin/tophat2"
	PATH_TO_CUTADAPT="/sw/apps/bioinfo/cutadapt/1.2.1/kalkyl/bin/cutadapt"
	PATH_TO_CUFFLINKS="/sw/apps/bioinfo/cufflinks/2.1.1/kalkyl/"
	PATH_TO_CUFFDIFF=$PATH_TO_CUFFLINKS
	GATK_BUNDLE_B37="/proj/b2010028/references/piper_references/gatk_bundle/2.2/b37"
	GATK_BUNDLE_HG19="/proj/b2010028/references/piper_references/gatk_bundle/2.2/hg19"
else
	JOB_RUNNER=" Shell"
	JOB_NATIVE_ARGS=""
	PATH_TO_BWA="/usr/bin/bwa"
	PATH_TO_SAMTOOLS="/usr/bin/samtools"
	PATH_TO_TOPHAT="/usr/local/bin/tophat2"
	PATH_TO_CUTADAPT="/usr/local/bin/cutadapt"
	PATH_TO_CUFFLINKS="$HOME/Bin/cufflinks/cufflinks"
	PATH_TO_CUFFDIFF=$PATH_TO_CUFFLINKS
	GATK_BUNDLE_B37="/local/data/gatk_bundle/b37"
	GATK_BUNDLE_HG19="/local/data/gatk_bundle/hg19"
fi

#---------------------------------------------
# Paths to general resources
#---------------------------------------------

DB_SNP_B37=${GATK_BUNDLE_B37}"/dbsnp_137.b37.vcf"
MILLS_B37=${GATK_BUNDLE_B37}"/Mills_and_1000G_gold_standard.indels.b37.vcf"
ONE_K_G_B37=${GATK_BUNDLE_B37}"/1000G_phase1.indels.b37.vcf"
HAPMAP_B37=${GATK_BUNDLE_B37}"/hapmap_3.3.b37.vcf"
OMNI_B37=${GATK_BUNDLE_B37}"/1000G_omni2.5.b37.vcf"
MILLS_B37=${GATK_BUNDLE_B37}"/Mills_and_1000G_gold_standard.indels.b37.vcf"

DB_SNP_HG19=${GATK_BUNDLE_H19}"/dbsnp_137.hg19.vcf"
MILLS_HG19=${GATK_BUNDLE_H19}"/Mills_and_1000G_gold_standard.indels.hg19.vcf"
ONE_K_G_HG19=${GATK_BUNDLE_H19}"/1000G_phase1.indels.hg19.vcf"
HAPMAP_H19=${GATK_BUNDLE_HG19}"/hapmap_3.3.hg19.vcf"
OMNI_HG19=${GATK_BUNDLE_HG19}"/1000G_omni2.5.hg19.vcf"
MILLS_HG19=${GATK_BUNDLE_HG19}"/Mills_and_1000G_gold_standard.indels.hg19.vcf"


#---------------------------------------------
# Global variables
#---------------------------------------------

# Note that the tmp folder needs to be placed in a location that can be reached from all nodes.
# Note that $SNIC_TMP cannot be used since that will lose necessary data as the nodes/core switch.
TMP=tmp/${PROJECT_NAME}

# Comment and uncomment DEBUG to enable/disable the debugging mode of the pipeline.
DEBUG="-l DEBUG" # -startFromScratch"

if [ ! -d "${TMP}" ]; then
   mkdir -p ${TMP}
fi
JAVA_TMP="-Djava.io.tmpdir="${TMP}

#This will execute the removal of the tmp directory
trap clean_up SIGHUP SIGINT SIGTERM

QUEUE="${PWD}/lib/Queue.jar"

SCRIPTS_DIR="${PWD}/qscripts"
NBR_OF_THREADS=8

# Setup directory structure
PIPELINE_OUTPUT="pipeline_output"
RAW_BAM_OUTPUT=$PIPELINE_OUTPUT"/bam_files_raw"
RAW_MERGED_BAM_OUTPUT=$PIPELINE_OUTPUT"/bam_files_raw_merged"
ALIGNMENT_QC_OUTPUT=$PIPELINE_OUTPUT"/alignment_qc"
PROCESSED_BAM_OUTPUT=$PIPELINE_OUTPUT"/bam_files_processed"
CUFFLINKS_OUTPUT=$PIPELINE_OUTPUT"/cufflinks"
CUFFDIFF_OUTPUT=$PIPELINE_OUTPUT"/cuffdiff"
VCF_OUTPUT=$PIPELINE_OUTPUT"/vcf_files"
LOGS=$PIPELINE_OUTPUT"/logs"
RNA_QC_OUTPUT=$PIPELINE_OUTPUT"/RNA_QC"

# -----------------
# Utility functions
# -----------------

# Setup temporary directory for the the Qscript tmp files.
# This will be removed as long as the script dies gracefully 
# (if it is killed with a kill -9, manual clean up will have to be run...)
function clean_up {
	# Perform program exit housekeeping
	rm -r ${TMP}
	exit
}

# Move reports etc.
function final_clean_up {
    # Move all the report files generated by Queue into a separate directory
    if [ ! -d "reports" ]; then
        mkdir "reports"
    fi

    mv *.jobreport.* reports/

    # Remove the file temporary directory - otherwise it will fill up glob. And all the files which are required for
    # the pipeline to run are written to the pipeline directory.
    clean_up
}
