#!/bin/bash -l
#SBATCH -A a2009002
#SBATCH -p core
#SBATCH -n 1
#SBATCH -t 120:00:00
#SBATCH -J piper
#SBATCH -o pipeline-%j.out
#SBATCH -e pipeline-%j.error

function usage {
   echo "Usage: ./workflows/Exome.sh --xml_input <setup.xml> <--sureselect> || <--truseq> [--alignments_only] [--run]"
}

# Loads the global settings. To change them open globalConfig.sh and rewrite them.
source globalConfig.sh

#---------------------------------------------
# Parse the arguments
#---------------------------------------------
PIPELINE_SETUP=""
RUN=""
ONLY_ALIGMENTS=""
INTERVALS=""

while :
    do
       case $1 in
           -h | --help | -\?)
               usage
               exit 0
               ;;
           -s | --xml_input)
               PIPELINE_SETUP=$2
               shift 2
               ;;
           -r | --run)
               RUN="-run"
               shift
               ;;
           -a | --alignments_only)
               ONLY_ALIGMENTS="--onlyAlignments"
               shift
               ;; 
           -e | --sureselect)
               INTERVALS="/proj/b2010028/references/piper_references/Enrichments/Agilent/SureSelect_All_Exon_50mb_with_annotation_hg19-gatk.interval_list"
               shift
               ;;
           -t | --truseq)
               INTERVALS="/proj/b2010028/references/piper_references/Enrichments/Illumina/TruSeq_exome_targeted_regions-gatk.interval_list"
               shift
               ;;          
           -*)
               echo "WARN: Unknown option (ignored): $1" >&2
               shift
               ;;
           *)  # no more options. Stop while loop
               break
               ;;
       esac
   done

if [ ! "$PIPELINE_SETUP" ]; then
   usage
   exit 1
fi

if [ ! "$INTERVALS" ]; then
   usage
   exit 1
fi
# We also need the correct java engine and R version
module load java/sun_jdk1.7.0_25
module load R/2.15.0

#---------------------------------------------
# Create output directories
#---------------------------------------------
if [ ! -d "${LOGS}" ]; then
   mkdir -p ${LOGS}
fi

#---------------------------------------------
# Run the qscript
#---------------------------------------------
source piper -S ${SCRIPTS_DIR}/DNABestPracticeVariantCalling.scala \
	     --xml_input ${PIPELINE_SETUP} \
             --isExome \
             --gatk_interval_file ${INTERVALS} \
	     --dbsnp ${DB_SNP_B37} \
             --extra_indels ${MILLS_B37} \
             --extra_indels ${ONE_K_G_B37} \
	     --hapmap ${HAPMAP_B37} \
	     --omni ${OMNI_B37} \
	     --mills ${MILLS_B37} \
	     -bwa ${PATH_TO_BWA} \
	     -samtools ${PATH_TO_SAMTOOLS} \
	     --number_of_threads 8 \
             --scatter_gather 10 \
	     -jobRunner ${JOB_RUNNER} \
             -jobNative "${JOB_NATIVE_ARGS}" \
	     --job_walltime 345600 \
	     ${RUN} ${ONLY_ALIGMENTS} ${DEBUG} 2>&1 | tee -a ${LOGS}/exome.log

# Perform final clean up
final_clean_up
