## Authors: Giacomo Pogliana, Lorenzo Ponzone

# Trio Variant Calling & Inheritance Filtering Pipeline

## Overview
This bash pipeline is designed to process genomic data for family trios (child, father, mother). It automates read alignment, quality control, variant calling, and disease-specific variant filtering based on user-defined clinical inheritance models. The pipeline specifically targets chromosome 20 (chr20) and uses a predefined exome panel BED file.

## Prerequisites & Dependencies
To run this pipeline, ensure the following bioinformatics tools are installed and accessible in your system's `$PATH`:
* **Bowtie2** (Alignment)
* **SAMtools** (BAM manipulation)
* **FastQC** (Quality control)
* **Qualimap** (BAM quality control)
* **BEDTools** (Genome coverage)
* **MultiQC** (Aggregated QC reporting)
* **FreeBayes** (Variant calling)
* **BCFtools & bgzip** (VCF manipulation and filtering)

## Directory Structure and Input Files
The script expects a specific directory structure to function correctly. You must run the script from a A main directory containing specific reference files. Within this directory, a specific subfolder for each trio, containing the respective paired-end FASTQ file.

**Required files in the main directory:**
* `chr20` (Bowtie2 index files for chromosome 20)
* `chr20.fa` (Reference genome FASTA for chromosome 20)
* `chr20_ILMN_Exome_2.0_Plus_Panel.hg38_padded.bed` (Target panel BED file)
* `samples.txt` (Sample list for BCFtools)

**Trio Subdirectories:**
Each trio must be in its own directory named with the prefix `trio_` (e.g., `trio_01/`, `trio_02/`).
Inside each trio directory, the script expects paired-end FASTQ files structured as `*.targets_R1.fq.gz` and `*.targets_R2.fq.gz`. 

> **⚠️ IMPORTANT:** The script assigns roles (child, father, mother) based on the alphabetical order of the FASTQ files in the directory. Ensure your files are named so that they sort in the following order:
> 1. Child
> 2. Father
> 3. Mother

## Usage
The pipeline categorizes each trio based on the inheritance model passed via command-line arguments. You must flag the inheritance mode, followed by the names of the trio directories that fall under that model.

**Syntax:**
```bash
./your_script_name.sh [INHERITANCE_FLAG] [trio_name1] [trio_name2] ...

