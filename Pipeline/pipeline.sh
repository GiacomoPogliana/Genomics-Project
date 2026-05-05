#!/bin/bash

# Input reading
input_AR=""
input_AD=""
input_ADM=""
input_ADF=""
mode_inherithance=""

# Loop over command arguments
for arg in "$@"; do
    if [ "$arg" = "-AR" ]; then
        mode_inherithance="AR"
    elif [ "$arg" = "-AD" ]; then
        mode_inherithance="AD"
    elif [ "$arg" = "-ADM" ]; then
        mode_inherithance="ADM"
    elif [ "$arg" = "-ADF" ]; then
        mode_inherithance="ADF"
    else
        if [ "$mode_inherithance" = "AR" ]; then
            input_AR="$input_AR $arg"
        elif [ "$mode_inherithance" = "AD" ]; then
            input_AD="$input_AD $arg"
        elif [ "$mode_inherithance" = "ADM" ]; then
            input_ADM="$input_ADM $arg"
        elif [ "$mode_inherithance" = "ADF" ]; then
            input_ADF="$input_ADF $arg"
        fi
    fi
done

echo "AR (Recessive)                    : $input_AR"
echo "AD (AD De Novo)                   : $input_AD"
echo "ADF (AD_inherited father affected): $input_ADF"
echo "ADM (AD_inherited mother affected): $input_ADM"
echo "Pipeline start"

# OUTER LOOP
for dir in trio_*/; do

    echo "Enter the directory: $dir"
    cd $dir
    
	# Get the name of current trio
    trio_name=${dir%/}
    
    index=0
    
    # INNER LOOP
    for fileR1 in *.targets_R1.fq.gz; do
        prefix=${fileR1%.targets_R1.fq.gz}
        fileR2="${prefix}.targets_R2.fq.gz"
        
        if [ $index -eq 0 ]; then
            role="child"
        elif [ $index -eq 1 ]; then
            role="father"
        elif [ $index -eq 2 ]; then
            role="mother"
        else
            echo "Error: unexpected fourth file was found"
            continue
        fi
        
        echo "Patient $prefix (Index $index) renamed to: $role"
        
        # Aligning
        echo "Aligning.."
        bowtie2 -x ../chr20 -1 $fileR1 -2 $fileR2 --rg-id "$role" --rg "SM:$role" -p 12 | samtools view -Sb | samtools sort -o ${role}.bam
        
        # FASTQC
        fastqc ${role}.bam
        
        # QUALIMAP
        qualimap bamqc -bam ${role}.bam --feature-file ../chr20_ILMN_Exome_2.0_Plus_Panel.hg38_padded.bed --outdir ${role}_qualimap_report
        
        # BEDTOOLS
        echo "Bedtools on ${role}.bam..."
        bedtools genomecov -ibam ${role}.bam -bg -trackline -trackopts "name=\"${trio_name}_${role}\"" -max 100 > ${trio_name}_${role}Cov.bg
        
        index=$((index + 1))
    done 
    
    # MULTIQC
    echo "multiqc.."
    multiqc .
    mv multiqc_report.html ${trio_name}_multiqc_report.html

    # FreeBayes
    echo "freebayes..."
    freebayes -f ../chr20.fa -m 20 -C 5 -Q 10 -q 10 --min-coverage 10 child.bam father.bam mother.bam > ${trio_name}.vcf
    
    # Compression and indexing
    bgzip -f ${trio_name}.vcf
    bcftools index -f ${trio_name}.vcf.gz

    # Disease filtering
    echo "Filter based on inheritance for $trio_name..."
    
    if [[ " $input_AR " =~ " $trio_name " ]]; then
        bcftools view -R ../chr20_ILMN_Exome_2.0_Plus_Panel.hg38_padded.bed ${trio_name}.vcf.gz | bcftools view -S ../samples.txt | bcftools view -i 'GT[0]="AA" && GT[1]="RA" && GT[2]="RA"' | bcftools filter -i 'QUAL>20' -Ov -o ${trio_name}_cand_AR.vcf
        
    elif [[ " $input_AD " =~ " $trio_name " ]]; then
        bcftools view -R ../chr20_ILMN_Exome_2.0_Plus_Panel.hg38_padded.bed ${trio_name}.vcf.gz | bcftools view -S ../samples.txt | bcftools view -i 'GT[0]="RA" && GT[1]="RR" && GT[2]="RR"' | bcftools filter -i 'QUAL>20' -Ov -o ${trio_name}_cand_AD_denovo.vcf
        
    elif [[ " $input_ADF " =~ " $trio_name " ]]; then
        bcftools view -R ../chr20_ILMN_Exome_2.0_Plus_Panel.hg38_padded.bed ${trio_name}.vcf.gz | bcftools view -S ../samples.txt | bcftools view -i 'GT[0]="RA" && GT[1]="RA" && GT[2]="RR"' | bcftools filter -i 'QUAL>20' -Ov -o ${trio_name}_cand_AD_inherited_father.vcf
        
    elif [[ " $input_ADM " =~ " $trio_name " ]]; then
        bcftools view -R ../chr20_ILMN_Exome_2.0_Plus_Panel.hg38_padded.bed ${trio_name}.vcf.gz | bcftools view -S ../samples.txt | bcftools view -i 'GT[0]="RA" && GT[1]="RR" && GT[2]="RA"' | bcftools filter -i 'QUAL>20' -Ov -o ${trio_name}_cand_AD_inherited_mother.vcf
        
    else
        echo "Error: No known clinical model for $trio_name"
    fi
    
    cd ..
    
done 

echo "Pipeline completed"
