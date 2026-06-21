#!/bin/bash


VCF_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/split_vcf" ##Change
OUT_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/out_str" ##Change
RESULT_DIR="$OUT_DIR/out_str" ##Change
MISMATCH_FILE="$OUT_DIR/mismatch_csv.txt" ##Change


# Set the target population
TARGET_POP="EUR" #Must be consistent with value entered in str_info2.sh


# Clear previous output
> "$MISMATCH_FILE"


for vcf_file in ${VCF_DIR}/popname_chr(num)_*.vcf.gz; do
    chunk=$(basename "$vcf_file" | sed -E 's/^popname_chr21_([0-9]{3})\.vcf\.gz$/\1/') ##Change
    echo "Processing $vcf_file (chunk $chunk)..."


    vcf_variants="/tmp/variants_vcf_${chunk}.txt"
    zgrep -v "^#" "$vcf_file" | awk -v OFS=":" '$1=="22"{print "chr"$1,$2,$4,$5}' | tr -d '[:space:]' > "$vcf_variants"


    echo "$(basename "$vcf_file")-" >> "$MISMATCH_FILE"


    result_file="$RESULT_DIR/$TARGET_POP/result_${TARGET_POP}_chr21_${chunk}.csv" ##Change
    echo -n "$TARGET_POP - " >> "$MISMATCH_FILE"


    if [[ -f "$result_file" ]]; then
        csv_variants="/tmp/variants_csv_${TARGET_POP}_${chunk}.txt"
        tail -n +2 "$result_file" | cut -d',' -f1 | tr -d '[:space:]' > "$csv_variants"


        missing=$(grep -Fxv -f "$csv_variants" "$vcf_variants" | paste -sd, -)


        if [[ -z "$missing" ]]; then
            echo "none" >> "$MISMATCH_FILE"
        else
            echo "$missing" >> "$MISMATCH_FILE"
        fi
    else
        echo "Result file not found!" >> "$MISMATCH_FILE"
    fi


    echo "" >> "$MISMATCH_FILE"
done


rm -f /tmp/variants_vcf_*.txt /tmp/variants_csv_*.txt


echo "Comparison completed. Check: $MISMATCH_FILE"









