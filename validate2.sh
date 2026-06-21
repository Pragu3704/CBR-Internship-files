#!/bin/bash
set -euo pipefail


CHUNK_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/split_vcf" ##Change
POPMAP_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/popmap" ##Change
OUT_BASE="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/out_str" ##Change
VCF_TO_STR_SCRIPT=/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/vcf_to_str_big.py" ##Change
INFOCALC_SCRIPT="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/infocalc.pl" ##Change


# Specify the target population here (e.g., AFR, EUR, etc.)
TARGET_POP="EUR" #Pop enetred here must be consistent with str_info2.sh POP vlaue enetred in POP=""


# Counters
STR_COUNT=0
CSV_COUNT=0


# Get all chunk files
chunks=($(ls "$CHUNK_DIR"/EUR_chr21_*.vcf.gz | sort)) ##Change
total_chunks=${#chunks[@]}


echo "Validating result CSV files for $total_chunks chunks for population $TARGET_POP..."


# Validation loop for specified population
for chunk_vcf in "${chunks[@]}"; do
    chunk_name=$(basename "$chunk_vcf" .vcf.gz)
    chunk_id="${chunk_name##*_}"


    popmap="$POPMAP_DIR/${TARGET_POP}.csv"
    str_out="$OUT_BASE/$TARGET_POP/out_${TARGET_POP}_chr21_${chunk_id}.str" ##Change
    result_out="$OUT_BASE/$TARGET_POP/result_${TARGET_POP}_chr21_${chunk_id}.csv" ##Change


    # Only check and regenerate if CSV is missing or empty
    if [[ ! -s "$result_out" ]]; then
        echo "Missing or empty CSV file: $result_out"
        echo "Regenerating STR for $TARGET_POP chunk $chunk_id"
        python "$VCF_TO_STR_SCRIPT" --vcf "$chunk_vcf" --popmap "$popmap" --out "$str_out"


        echo "Regenerating result CSV for $TARGET_POP chunk $chunk_id"
        perl "$INFOCALC_SCRIPT" -input "$str_out" -output "$result_out" -column 2 -numpops 2


        # If CSV is successfully generated and non-empty, delete the STR file
        if [[ -s "$result_out" ]]; then
            rm -f "$str_out"
            ((CSV_COUNT++))
        else
            echo "ERROR: CSV generation failed for $TARGET_POP chunk $chunk_id"
        fi
    else
        ((CSV_COUNT++))
        ((STR_COUNT++))  # We assume STR was previously valid and deleted
    fi
done


# Final summary
echo ""
echo "Validation complete for population $TARGET_POP."
echo "Total chunks: $total_chunks"
echo "$TARGET_POP: $STR_COUNT valid STR files, $CSV_COUNT valid CSV files"



