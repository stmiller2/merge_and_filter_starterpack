#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: merge_reads.sh <params_file>"
  exit 1
fi

#Get params
params_file="$1"
source "$params_file"

# Start clock
start_time=$(date --utc +%s)

# Set up file structure
cd ${path}
exec &> run_progress.log
mkdir ${path}/csvs/
rm ${path}/Fastq/paste_fastq_files_here

if [ "$reorg" == "TRUE" ]; then
    mkdir ${path}/csvs/raw/
    mkdir ${path}/csvs/raw/good_reads/
    mkdir ${path}/csvs/raw/poor_reads/
    mkdir ${path}/csvs/raw/info/
    mkdir ${path}/csvs/raw/combined/
fi

# Iterate through the sample names and merge reads
for i in "${sample_names[@]}"; do
	echo -e "\033[1m$(printf %80s |tr " " "=")\033[0m\n"
	echo -e "\033[1m$(printf %$(((80-(18+${#i}))/2))s |tr " " " ")PROCESSING SAMPLE $i\033[0m\n"
	echo -e "\033[1m$(printf %80s |tr " " "=")\033[0m"

	mkdir ${path}/Fastq/${i}/
	cd ${path}/Fastq/${i}/
	mv ../${i}_* . 
	
	if [ "$merge" == "TRUE" ]; then
		echo -e "\n$(date '+%I:%M%p') -- MERGING PAIRED-END READS"
		${pear} -f *_R1_001.fastq.gz -r *_R2_001.fastq.gz -o combined -y ${memory} -j ${cpus} -v ${pear_overlap} -g ${pear_stattest} -p ${pear_pvalue} \
		| grep -E -m 3 "Assembled reads|Discarded reads|Not assembled reads" | awk 'NF' | sed 's/^/           /'
	
		echo -e "$(date '+%I:%M%p') -- READS MERGED"
		echo -e "\n$(date '+%I:%M%p') -- FORMATTING MERGED READS"
	
		# Detect and strip headers starting with @ followed by any non-space characters
		sed -E '/^@[A-Z0-9-]+/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
	
		echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
	fi

	
	if [[ "$merge" == "FALSE" && "$singleend" == "FALSE" ]]; then
		echo -e "\n$(date '+%I:%M%p') -- CONCATENATING PAIRED-END READS"
		awk 'NR % 4 == 2 { system("echo " $0 " | tr \"ATGCatgc\" \"TACGtacg\" | rev") } NR % 4 != 2 { print $0 }' *_R2_001.fastq > R2_rc.fastq
		paste -d "" *_R1_001.fastq R2_rc.fastq > combined.assembled.fastq
		echo -e "$(date '+%I:%M%p') -- READS MERGED"
		echo -e "\n$(date '+%I:%M%p') -- FORMATTING MERGED READS"
	
		# Detect and strip headers starting with @ followed by any non-space characters
		sed -E '/^@[A-Z0-9-]+/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
	
		echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
	fi
	
	if [[ "$merge" == "FALSE" && "$singleend" == "TRUE" ]]; then
		echo -e "\n$(date '+%I:%M%p') -- FORMATTING MERGED READS"
	
		# Detect and strip headers starting with @ followed by any non-space characters
		sed -E '/^@[A-Z0-9-]+/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
	
		echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
	fi
	
	# Quality filtering
	cp ${path}/pipeline/QF3.out ${path}/Fastq/${i}
	echo -e "\n$(date '+%I:%M%p') -- FILTERING FOR HIGH QUALITY READS"
	./QF3.out
	echo -e "$(date '+%I:%M%p') -- QUALITY FILTERING COMPLETE"
	rm QF3.out
	
	# Calculate filtering statistics
	cp ${path}/pipeline/get_stats.sh ${path}/Fastq/${i}
	echo -e "\n$(date '+%I:%M%p') -- GETTING ASSEMBLY AND FILTERING STATISTICS"
	./get_stats.sh
	echo -e "$(date '+%I:%M%p') -- READ FATES WRITTEN TO INFO.CSV"
	rm get_stats.sh
	
	# Reorganize files if requested
	if [ "$reorg" == "TRUE" ]; then
	    echo -e "\n$(date '+%I:%M%p') -- REORGANIZING FILES"
    	mv good_reads.csv ${path}/csvs/raw/good_reads/good_reads_${i}.csv
    	mv poor_reads.csv ${path}/csvs/raw/poor_reads/poor_reads_${i}.csv
    	mv info.csv ${path}/csvs/raw/info/info_${i}.csv
    	mv combined.fastq ${path}/csvs/raw/combined/combined_${i}.fastq
    	echo -e "$(date '+%I:%M%p') -- REORGANIZATION COMPLETE"
	else
    	echo -e "\n$(date '+%I:%M%p') -- NO REORGANIZATION REQUESTED. FIND GOOD_READS WITHIN FASTQ SUBDIRECTORIES."
	fi
	echo -e "\nSAMPLE $i COMPLETE\n\n"
done

end_time=$(date --utc +%s)
runtime=$((end_time-start_time))

echo -e "$(date '+%I:%M%p') -- Done. Total runtime: $(date -u -d @${runtime} +%H:%M:%S)"
