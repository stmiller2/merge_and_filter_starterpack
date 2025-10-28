# Silas' NGS Processing Pipeline - Version 8, Updated 01/08/2025
*Contact: stmiller2@wisc.edu*

Overview:
---------
This pipeline facilitates the merging of paired-end reads and quality filtering 
for Next-Generation Sequencing (NGS) data. There are options for processing 
single-end reads or paired-end reads without overlap, as well. Follow the steps
below to process your experiment efficiently.

Usage Instructions:
-------------------

**STEP 1:** Copy the entire merge_and_filter_starterpack directory and rename
 it to reflect your experiment.

**STEP 2:** Move all your fastq files from the sequencer to the 'Fastq/' 
 directory. Filenames should follow this format:
	- `{samplename}_S{#}_L001_R1_001.fastq.gz` #Forward read
	- `{samplename}_S{#}_L001_R2_001_fastq.gz` #Reverse read (paired-end only)

**STEP 3:** Set parameters in the `params.csv` file:

| PARAMETER         | VALUE        | DESCRIPTION |
|-------------------|--------------|--------------|
| data_filepath     | filepath     | Path to the file you are running this pipeline in |
| pear_filepath     | filepath     | Path to the PEAR executable |
| pear_overlap      | int          | Minimum overlap for merging (see PEAR docs) - suggest 10 |
| pear_stattest     | int          | PEAR merging statistical test (see PEAR docs) - suggest 1 |
| pear_pvalue       | float        | P-value for PEAR statistical test. Set to 1.0 to disable the statistical test. |
| merge             | TRUE/FALSE   | Should typically be set to TRUE - merges reads with PEAR. If FALSE, all PEAR parameters are ignored and reads are simply concatenated. Very slow. |
| singleend         | TRUE/FALSE   | FALSE for merging paired-end reads; TRUE for formatting & filtering single-end reads. |
| compiler_filepath | filepath     | Path to g++ executable (C++ compiler) |
| cpus              | int          | Number of cores requested - suggest 8 |
| memory            | int + unit   | Amount of RAM requested - suggest 2G |
| disk              | int + unit   | Amount of disk space requested - suggest 60G |
| instrument        | string       | Instrument used to collect the data - miseq/nextseq/novaseq/nextseq_fox |
| q_floor           | int          | Reads with any bases below this value are discarded |
| q_cutoff          | int          | Reads with too many bases below this value are discarded (see cutoff_pct) |
| cutoff_pct        | float        | Proportion of bases that must be at or above q_cutoff for a read to be kept |
| sample_names      | strings      | List all sample names, each in their own column, as they appear in output Fastq files |
| reorganize        | TRUE/FALSE   | If true, all final "good_reads.csv" files (and others) will be reorganized into a single directory |


**STEP 4:** Move the entire directory to your scratch folder 
		`cp -r {directory name} /scratch/{wiscID}`

**STEP 5:** Start the processing run with the following command:
		`./process_ngs.sh params.csv`
	    Params will print to the console -- double check everything is
	    set correctly. 

**STEP 6:** Monitor the run progress via `run_progress.log`:
		`tail -f -n 50 run_progress.log` (exit using ctrl+C)

**STEP 7:** When finished, move the entire directory back to the fileserver.

**STEP 8:** Profit???
--------------------------------------------------------------------------------
