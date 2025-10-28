#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 15 ]; then
  echo "Did not recieve expected number of arguments. Check process_ngs.sh, which creates the submit file."
  exit 1
fi

# Start clock
start_time=$(date --utc +%s)

# Get params from submit file arguments
path=${1}
pear=${2}
pear_overlap=${3}
pear_stattest=${4}
pear_pvalue=${5}
merge=${6}
singleend=${7}
cpus=${8}
memory=${9}
instrument=${10}
q_floor=${11}
q_cutoff=${12}
cutoff_pct=${13}
sample_names_line=${14}
reorg=${15}

# Split sample_names_line into iterable
IFS=',' read -r -a sample_names <<< "$(echo "$sample_names_line" | cut -d ',' -f 2-)"

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
		${pear} -f *_R1_001.fastq.gz -r *_R2_001.fastq.gz -o combined -y ${memory} -j ${cpus} -v ${pear_overlap} -g ${pear_stattest} -p ${pear_pvalue} | grep -E -m 3 "Assembled reads|Discarded reads|Not assembled reads" | awk 'NF' | sed 's/^/           /'
		echo -e "$(date '+%I:%M%p') -- READS MERGED"
		echo -e "\n$(date '+%I:%M%p') -- FORMATTING MERGED READS"
		if [ "$instrument" == "miseq" ]; then
			sed '/@M07074/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "nextseq" ]; then
			sed '/@VL00209/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "nextseq_fox" ]; then
			sed '/@VL00232/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "novaseq" ]; then
			sed '/@LH00283/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		else
			echo -e "$(date '+%I:%M%p') -- INVALID INSTRUMENT ID. OUTPUT FILE COULD NOT BE FORMATTED."
		fi
	fi
	
	if [[ "$merge" == "FALSE" && "$singleend" == "FALSE" ]]; then
		echo -e "\n$(date '+%I:%M%p') -- CONCATENATING PAIRED-END READS"
		awk 'NR % 4 == 2 { system("echo " $0 " | tr \"ATGCatgc\" \"TACGtacg\" | rev") } NR % 4 != 2 { print $0 }' *_R2_001.fastq > R2_rc.fastq
		paste -d "" *_R1_001.fastq R2_rc.fastq > combined.assembled.fastq
		echo -e "$(date '+%I:%M%p') -- READS MERGED"
		echo -e "\n$(date '+%I:%M%p') -- FORMATTING MERGED READS"
		if [ "$instrument" == "miseq" ]; then
			sed '/@M07074/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "nextseq" ]; then
			sed '/@VL00209/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "nextseq_fox" ]; then
			sed '/@VL00232/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "novaseq" ]; then
			sed '/@LH00283/d' combined.assembled.fastq | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		else
			echo -e "$(date '+%I:%M%p') -- INVALID INSTRUMENT ID. OUTPUT FILE COULD NOT BE FORMATTED."
		fi
	fi
	
	if [[ "$merge" == "FALSE" && "$singleend" == "TRUE" ]]; then
		echo -e "\n$(date '+%I:%M%p') -- FORMATTING SINGLE-END READS"
		if [ "$instrument" == "miseq" ]; then
			sed '/@M07074/d' ${i}_* | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "nextseq" ]; then
			sed '/@VL00209/d' ${i}_* | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "nextseq_fox" ]; then
			sed '/@VL00232/d' ${i}_* | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		elif [ "$instrument" == "novaseq" ]; then
			sed '/@LH00283/d' ${i}_* | sed '2~3d' | sed 'N;s/\n/ /' > combined.fastq
			echo -e "$(date '+%I:%M%p') -- READS FORMATTED"
		else
			echo -e "$(date '+%I:%M%p') -- INVALID INSTRUMENT ID. OUTPUT FILE COULD NOT BE FORMATTED."
		fi
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