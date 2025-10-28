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

transfer_input_files = ${data_filepath}/${params_file}

initialdir = ${data_filepath}/pipeline

request_cpus = ${cpus}
request_memory = ${memory}
request_disk = ${disk}

queue 1
EOF

# Submit the job with condor_submit
condor_submit process_ngs.sub

# Prepare C++ source from template
template_file="QF3_template.cpp"
output_cpp="QF3.cpp"

# Replace placeholders in template with actual parameter values
sed -e "s/{{Q_FLOOR}}/$q_floor/" \
    -e "s/{{Q_CUTOFF}}/$q_cutoff/" \
    -e "s/{{CUTOFF_PCT}}/$cutoff_pct/" \
    "$template_file" > "$output_cpp"

# Compile the quality filtering script (static compiling allows this to run through a cluster job)
${compiler_filepath} -static-libstdc++ -o QF3.out "$output_cpp"