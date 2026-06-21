#!/bin/bash
set -euo pipefail


# Configuration
TARGET_POP="EUR"  # Set the population you want to process (e.g., SAS, AFR, etc.), must be consistent with one used in str_info2.sh, validate2.sh, mismatch_csv2.sh
RESULT_DIR="/gpfs/data/user/pragathi/chr21_infocalc/EUR_chr21/out_str" ##Change
MERGE_DIR="/gpfs/data/user/pragathi/chr21_infocalc/EUR_chr21/infocalc_output” ##Change


# Ensure output directory exists
mkdir -p "$MERGE_DIR"


# Merge files for the specified population
echo "Merging result files for $TARGET_POP..."
out_file="$MERGE_DIR/infocalc_${TARGET_POP}.csv"
> "$out_file"


# Get sorted list of result files
result_files=($(ls "$RESULT_DIR/$TARGET_POP"/result_${TARGET_POP}_chr21_*.csv | sort)) ##Change


for idx in "${!result_files[@]}"; do
    file="${result_files[$idx]}"


    if [[ $idx -eq 0 ]]; then
        # First file (e.g. 001): keep header but remove 2nd line and last 2 lines
        {
            head -n 1 "$file"               # Header
            tail -n +3 "$file" | head -n -2
        } >> "$out_file"
    else
        # Other files: remove first 2 lines and last 2 lines
        tail -n +3 "$file" | head -n -2 >> "$out_file"
    fi
done


echo "Merged output written to $out_file"
echo "All populations merged."









