#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <params_file.env>"
  exit 1
fi

params_file=$1

# Check if the params file exists
if [ ! -f "$params_file" ]; then
  echo "Error: Params file '$params_file' not found."
  exit 1
fi

# Get parameters from params file
source "$params_file"

# Print parameters to the terminal
echo "================ Parameter Settings ================"
echo "Data Filepath       : $data_filepath"
echo "Pear Filepath       : $pear_filepath"
echo "Pear Overlap        : $pear_overlap"
echo "Pear Stat Test      : $pear_stattest"
echo "Pear P-value        : $pear_pvalue"
echo "Merge               : $merge"
echo "Single-end          : $singleend"
echo "Compiler Filepath   : $compiler_filepath"
echo "CPUs                : $cpus"
echo "Memory              : $memory"
echo "Disk                : $disk"
echo "Q Floor             : $q_floor"
echo "Q Cutoff            : $q_cutoff"
echo "Cutoff Percent      : $cutoff_pct"
echo "Sample Names        : $sample_names"
echo "Reorganize          : $reorganize"
echo "===================================================="

if [[ "$merge" == "TRUE" && "$singleend" == "TRUE" ]]; then
  echo "Error: merge is set to TRUE, which implies paired-end reads, but singleend is also TRUE. Check params.csv"
  exit 1
fi

if [[ "$merge" == "FALSE" || "$singleend" == "TRUE" ]]; then
    cd ${data_filepath}/Fastq
    gunzip *.fastq.gz
fi

cd ${data_filepath}/pipeline

# Create condor submit file
cat <<EOF > process_ngs.sub
universe = vanilla
log = condor.log
error = condor.err

executable = merge_reads.sh
arguments = $params_file

initialdir = ${data_filepath}/pipeline

request_cpus = ${cpus}
request_memory = ${memory}
request_disk = ${disk}

queue 1
EOF

# Submit the job with condor_submit
condor_submit process_ngs.sub

# Create quality filtering C++ script
cat << EOF > QF3.cpp
#include <fstream>
#include <iostream>
#include <string>
#include <math.h>
using namespace std;

int q_floor = ${q_floor};			//q_floor set using params.csv
int q_cutoff = ${q_cutoff};			//q_cutoff set using params.csv
float cutoff_pct = ${cutoff_pct};	//cutoff_pct set using params.csv

int main()
{
	//Initialize variables and open file streams
	string inMPERs="combined.fastq";
	ifstream inRawReads(inMPERs.c_str());
	ofstream outGoodReads("good_reads.csv"), outPoorReads("poor_reads.csv");
	size_t split;				//position of the split between sequence & quality string
	double q, g, pct;			//Q-score, # bases > q_cutoff, % bases > q_cutoff
	int j;						//sequence position when looping through quality string
	string line, seq, qual;		//combined.fastq line, DNA sequence, quality string
	bool discarded;				//whether read contains bases < q_floor
	
	//Print quality filtering variables to the console
	cout << "           Quality filtering settings:" << '\n' << '\t';
	cout << "           Proportion >=Q" << q_cutoff << " must be above " << cutoff_pct << '\n' << '\t';
	cout << "           All bases must have a Q-score >= Q" << q_floor << '\n';
	
	while(getline(inRawReads,line))
	{
		split = line.find(" ");				//Get split position
		qual = line.substr(split + 1);		//Get quality sequence
		seq = line.substr(0, split);		//Get DNA sequence

		g = 0;
		discarded = false;
		
		for(j=0; j < qual.length(); j++)	//For each character in the quality string
		{
			q = double(qual[j]) - 33;		//Convert character to Q-score (ASCII - 33)
			if(q < q_floor)					//If base quality is < q_floor,
			{
				discarded = true;			//mark sequence as discarded
				break;						//and break the for loop (ignore further bases)
			} else
			{
				if(q >= q_cutoff)			//If base quality is >= q_cutoff
				{
					g = g + 1;				//Add one to g (good bases count)
				}
			}
		}
		if(discarded == false)				//If sequence isn't already marked discarded,
		{
			pct = g / qual.length();		//Calculate percent bases >= q_cutoff
			if(pct > cutoff_pct)			//If percent meets standards,
			{
				outGoodReads << seq << '\n';//Write seq to good_reads.csv
			} else							//If not,
			{								//Write seq to poor_reads.csv
				//Include "E2" classification and actual percent >=q_cutoff
				outPoorReads << seq << "," << "E2" << "," << pct << '\n';
			}
		} else								//If sequence is already marked discarded,
		{									//Write seq to poor_reads.csv
			//Include "E1" classification and position of first subthreshold base
			outPoorReads << seq << "," << "E1" << "," << j << '\n';
		}
	}
	inRawReads.close();
	outGoodReads.close();
	outPoorReads.close();
	
	cout << "           High quality reads written to 'good_reads.csv'" << '\n';
	cout << "           Low quality reads written to 'poor_reads.csv'" << '\n' << '\t';
	cout << "           'E1' - 1+ bases < Q" << q_floor << " (first base index shown)" << '\n' << '\t';
	cout << "           'E2' - < " << cutoff_pct << " Q" << q_cutoff << " (actual percentage shown)" << '\n';

	return 0;
}
EOF

# Compile the quality filtering script (static compiling allows this to run through a cluster job)
${compiler_filepath} -static-libstdc++ -o QF3.out QF3.cpp
