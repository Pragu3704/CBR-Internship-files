#!/bin/bash
set -euo pipefail


CHUNK_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/split_vcf" ##Change
POPMAP_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/popmap" ##Change
OUT_BASE="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/out_str" ##Change
VCF_TO_STR_SCRIPT="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/vcf_to_str_big.py" ##Change
INFOCALC_SCRIPT="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/infocalc.pl" ##Change
POP="EUR" #Enter based on for popmap u wanna process### (format - SAS, EUR, etc)
MAX_PARALLEL=1 #do not make changes


# Create output directory if not already present
mkdir -p "$OUT_BASE/$POP"


# Get sorted list of chunks
chunks=()
while IFS= read -r file; do
    chunks+=("$file")
done < <(find "$CHUNK_DIR" -maxdepth 1 -name 'EUR_chr21_*.vcf.gz' | sort) ##Change
total_chunks=${#chunks[@]}


# === EARLY CHECK: ONLY CHECK FOR CSV FILES ===
echo "Checking existing result CSV files for all chunks for $POP..."


all_csv_present=true
for chunk_vcf in "${chunks[@]}"; do
    chunk_name=$(basename "$chunk_vcf" .vcf.gz)
    raw_id="${chunk_name##*_}"
    chunk_id=$(printf "%03d" "$((10#$raw_id))")


    csv_file="$OUT_BASE/$POP/result_${POP}_chr21_${chunk_id}.csv" ##Change


    if [[ ! -s "$csv_file" ]]; then
        all_csv_present=false
    fi
done


if $all_csv_present; then
    echo "All result CSV files exist and are non-empty. Skipping generation."
    exit 0
else
    echo "Some result CSV files are missing or empty. Proceeding with generation."
fi


# === MAIN PROCESS (generates missing CSVs,deletes .str) ===
process_chunk() {
    chunk_vcf="$1"
    chunk_name=$(basename "$chunk_vcf" .vcf.gz)
    raw_id="${chunk_name##*_}"
    chunk_id=$(printf "%03d" "$((10#$raw_id))")


    (
        str_out="$OUT_BASE/$POP/out_${POP}_chr21_${chunk_id}.str" ##Change
        result_out="$OUT_BASE/$POP/result_${POP}_chr21_${chunk_id}.csv" ##Change
        popmap="$POPMAP_DIR/${POP}.csv"


        if [[ -s "$result_out" ]]; then
            echo "[$(date '+%H:%M:%S')] Skipping $chunk_id for $POP (CSV exists)"
            exit 0
        fi


        echo "[$(date '+%H:%M:%S')] Processing chunk $chunk_id for $POP"


        # Ensure clean state
        rm -f "$str_out" "$result_out"


        # Generate .str file
        python "$VCF_TO_STR_SCRIPT" --vcf "$chunk_vcf" --popmap "$popmap" --out "$str_out"


        # Generate result .csv
        perl "$INFOCALC_SCRIPT" -input "$str_out" -output "$result_out" -column 2 -numpops 2


        # Check if CSV is created and non-empty, then delete the .str file
        if [[ -s "$result_out" ]]; then
            rm -f "$str_out"
            echo "[$(date '+%H:%M:%S')] Done: $chunk_id | $POP (STR deleted)"
        else
            echo "[$(date '+%H:%M:%S')] ERROR: CSV generation failed for $chunk_id | $POP"
        fi
    ) &
}


# === PARALLEL PROCESSING ===
i=0
while [ $i -lt ${#chunks[@]} ]; do
    pids=()


    for j in $(seq 0 $((MAX_PARALLEL - 1))); do
        index=$((i + j))
        if [ $index -lt ${#chunks[@]} ]; then
            process_chunk "${chunks[$index]}"
            pids+=($!)
        fi
    done


    for pid in "${pids[@]}"; do
        wait "$pid"
    done


    i=$((i + MAX_PARALLEL))
done


echo "All chunks processed for $POP."









