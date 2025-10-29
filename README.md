# NGS Processing Pipeline - Version 9
**Updated:** 10/28/2025

**Contact:** stmiller2@wisc.edu

---

## Overview
This pipeline facilitates the merging of paired-end reads and quality filtering for Next-Generation Sequencing (NGS) data. It also supports processing single-end reads or paired-end reads without overlap. Follow the steps below to process your experiment efficiently.

---

## Usage Instructions

### STEP 1
Clone the `merge_and_filter_starterpack` GitHub repo and rename it to reflect your experiment.
```
git clone https://github.com/stmiller2/merge_and_filter_starterpack
mv merge_and_filter_starterpack/ my_experiment/
```

### STEP 2
Move all your fastq files from the sequencer to the `Fastq/` directory. Filenames should follow this format:
- `{samplename}_S{#}_L001_R1_001.fastq.gz` – Forward read  
- `{samplename}_S{#}_L001_R2_001.fastq.gz` – Reverse read (paired-end only)

### STEP 3
Set parameters in the `params.env` file:

| PARAMETER         | VALUE      | DESCRIPTION |
|-------------------|------------|-------------|
| data_filepath     | filepath   | Path to the file you are running this pipeline in |
| pear_filepath     | filepath   | Path to the PEAR executable |
| pear_overlap      | int        | Minimum overlap for merging (see PEAR docs) – suggest 10 |
| pear_stattest     | int        | PEAR merging statistical test (see PEAR docs) – suggest 1 |
| pear_pvalue       | float      | P-value for PEAR statistical test. Set to 1.0 to disable the test |
| merge             | TRUE/FALSE | Typically TRUE – merges reads with PEAR. If FALSE, PEAR parameters are ignored and R1 is concatenated to the reverse complement of R2 |
| singleend         | TRUE/FALSE | FALSE for merging paired-end reads; TRUE for formatting & filtering single-end reads |
| compiler_filepath | filepath   | Path to g++ executable (C++ compiler) |
| cpus              | int        | Number of cores requested – suggest 8 |
| memory            | int + unit | Amount of RAM requested – suggest 2G |
| disk              | int + unit | Amount of disk space requested – suggest 60G |
| q_floor           | int        | Reads with any bases below this value are discarded |
| q_cutoff          | int        | Reads with too many bases below this value are discarded (see cutoff_pct) |
| cutoff_pct        | float      | Proportion of bases that must be at or above q_cutoff for a read to be kept |
| sample_names      | strings    | List all sample names, each in its own column, as they appear in output Fastq files |
| reorganize        | TRUE/FALSE | If TRUE, all final `good_reads.csv` files (and others) will be reorganized into a single directory |

### STEP 4
Move the entire directory to your scratch folder:
```
cp -r {directory name} /scratch/{wiscID}
```

### STEP 5: Start the processing run
```
chmod +x process_ngs.sh
./process_ngs.sh params.csv
```

Params will print to the console -- double check everything is set correctly. 

### STEP 6: Monitor the run progress
```
tail -f -n 50 run_progress.log
```
(exit using ctrl+C)

### STEP 7: When finished, move the entire directory back to the fileserver.

### STEP 8: Publish CNS
