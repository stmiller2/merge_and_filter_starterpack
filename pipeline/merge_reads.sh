#!/bin/bash

# Check for correct number of arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: merge_reads.sh <params_file>"
  exit 1
fi

# Load parameters
params_file="$1"
source "$params_file"

# Start clock
start_time=$(date --utc +%s)

# Setup
cd "${data_filepath}" || exit
exec &> run_progress.log
mkdir -p "${data_filepath}/csvs/"
rm -f "${data_filepath}/Fastq/paste_fastq_files_here"

if [ "$reorganize" == "TRUE" ]; then
    mkdir -p "${data_filepath}/csvs/raw"/{good_reads,poor_reads,info,combined}
fi

# Log helper
log() {
    local type="$1"
    local msg="$2"
    if [ "$type" == "start" ]; then
        echo -e "\n$(date '+%I:%M%p') -- $msg"
    else
        echo -e "$(date '+%I:%M%p') -- $msg"
    fi
}

# Function to format reads
format_reads() {
    local target_file="$1"
    echo -e "\n$(date '+%I:%M%p') -- FORMATTING READS"
    paste -d '\t' - - - - < "$target_file" | awk -F '\t' '{print $2, $4}' > combined.fastq #Keep every second and fourth line, combined & separated by a space
    echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
}


# Iterate through samples
IFS=',' read -r -a sample_names_array <<< "$sample_names"
for i in "${sample_names_array[@]}"; do
	echo -e "\033[1m$(printf %80s |tr " " "=")\033[0m\n"
	echo -e "\033[1m$(printf %$(((80-(18+${#i}))/2))s |tr " " " ")PROCESSING SAMPLE $i\033[0m\n"
	echo -e "\033[1m$(printf %80s |tr " " "=")\033[0m"

    # Prepare sample directory
    mkdir -p "${data_filepath}/Fastq/${i}/"
    cd "${data_filepath}/Fastq/${i}/" || exit
    mv ../"${i}"_* .

    # Merge or concatenate reads
    if [ "$merge" == "TRUE" ]; then
        log start "MERGING PAIRED-END READS"
        "${pear_filepath}" -f *_R1_001.fastq.gz -r *_R2_001.fastq.gz -o combined \
            -y "${memory}" -j "${cpus}" -v "${pear_overlap}" -g "${pear_stattest}" -p "${pear_pvalue}" \
            | grep -E -m 3 "Assembled reads|Discarded reads|Not assembled reads" | awk 'NF' | sed 's/^/           /'
        log stop "READS MERGED"
        format_reads combined.assembled.fastq
    elif [ "$singleend" == "FALSE" ]; then
        log start "CREATING REVERSE COMPLEMENT OF READ 2"
        awk '{
        	if(NR%4==2){
            	seq=$0
            	gsub("A","t",seq); gsub("T","a",seq); gsub("G","c",seq); gsub("C","g",seq)
            	n = length(seq); rc=""
            	for(i=n;i>=1;i--){rc=rc toupper(substr(seq,i,1))}
            	print rc
        	} else {print}
   		}' *_R2_001.fastq > R2_rc.fastq
        log stop "REVERSE COMPLEMENTED"
        log start "CONCATENATING PAIRED-END READS"
        paste -d "" *_R1_001.fastq R2_rc.fastq > combined.assembled.fastq
        log stop "READS MERGED"
        format_reads combined.assembled.fastq
        rm R2_rc.fastq
    else
        format_reads "${i}"_*
    fi

    # Quality filtering
    cp "${data_filepath}/pipeline/QF3.out" .
    log start "FILTERING FOR HIGH QUALITY READS"
    ./QF3.out
    log stop "QUALITY FILTERING COMPLETE"
    rm QF3.out

    # Stats calculation
    cp "${data_filepath}/pipeline/get_stats.sh" .
    log start "GETTING ASSEMBLY AND FILTERING STATISTICS"
    chmod +x get_stats.sh
    ./get_stats.sh
    log stop "READ FATES WRITTEN TO INFO.CSV"
    rm get_stats.sh

    # Reorganize files
    if [ "$reorganize" == "TRUE" ]; then
        log start "REORGANIZING FILES"
        mv good_reads.csv "${data_filepath}/csvs/raw/good_reads/good_reads_${i}.csv"
        mv poor_reads.csv "${data_filepath}/csvs/raw/poor_reads/poor_reads_${i}.csv"
        mv info.csv "${data_filepath}/csvs/raw/info/info_${i}.csv"
        mv combined.fastq "${data_filepath}/csvs/raw/combined/combined_${i}.fastq"
        log stop "REORGANIZATION COMPLETE"
    else
        log start "NO REORGANIZATION REQUESTED. FIND GOOD_READS WITHIN FASTQ SUBDIRECTORIES."
    fi

    echo -e "\nSAMPLE $i COMPLETE\n\n"
done

# Finish
end_time=$(date --utc +%s)
runtime=$((end_time - start_time))
log stop "Done. Total runtime: $(date -u -d "@${runtime}" +%H:%M:%S)"
