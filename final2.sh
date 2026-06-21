#!/bin/bash
set -euo pipefail


module avail bcftools
module load bcftools-1.21
module avail htslib
module load htslib-1.18
module avail python
module load python3.11.4
export LD_LIBRARY_PATH=$HOME/openssl-1.1/lib:$LD_LIBRARY_PATH
export PATH=$HOME/openssl-1.1/bin:$PATH




SCRIPT_DIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21" ##Change
LOG_FILE="$SCRIPT_DIR/infocalc.log"


# Start fresh log
echo "Starting INFOCALC pipeline at $(date)" > "$LOG_FILE"


# Scripts to run sequentially before mismatch
INITIAL_SCRIPTS=(
    "split_vcf.sh"
    "str_info2.sh"
    "validate2.sh"
)


# Run initial scripts
for script in "${INITIAL_SCRIPTS[@]}"; do
    script_path="$SCRIPT_DIR/$script"


    echo "------------------------------------------------------------" >> "$LOG_FILE"
    echo "Running $script at $(date)" >> "$LOG_FILE"


    if [[ ! -f "$script_path" ]]; then
        echo "ERROR: $script_path not found. Skipping." >> "$LOG_FILE"
        continue
    fi


    if ! bash "$script_path" >> "$LOG_FILE" 2>&1; then
        echo "ERROR: $script failed. Exiting." >> "$LOG_FILE"
        exit 1
    fi


    echo "Finished $script at $(date)" >> "$LOG_FILE"
    echo "------------------------------------------------------------" >> "$LOG_FILE"
done


# Run only mismatch_csv2.sh
echo "------------------------------------------------------------" >> "$LOG_FILE"
echo "Running mismatch_csv2.sh at $(date)" >> "$LOG_FILE"


if bash "$SCRIPT_DIR/mismatch_csv2.sh" >> "$LOG_FILE" 2>&1; then
    echo "mismatch_csv2.sh completed successfully." >> "$LOG_FILE"
   
    # Delete split_vcf directory
    SPLIT_VCF_DIR="$SCRIPT_DIR/split_vcf"
    if [[ -d "$SPLIT_VCF_DIR" ]]; then
        rm -rf "$SPLIT_VCF_DIR"
        echo "Deleted $SPLIT_VCF_DIR after successful mismatch_csv2.sh." >> "$LOG_FILE"
    fi
else
    echo "WARNING: mismatch_csv2.sh failed. Proceeding anyway without deleting split_vcf." >> "$LOG_FILE"
fi


echo "Finished mismatch_csv2.sh at $(date)" >> "$LOG_FILE"
echo "------------------------------------------------------------" >> "$LOG_FILE"




# Run merge script
MERGE_SCRIPTS=(
    "merge_csv2.sh"
)


for script in "${MERGE_SCRIPTS[@]}"; do
    script_path="$SCRIPT_DIR/$script"


    echo "------------------------------------------------------------" >> "$LOG_FILE"
    echo "Running $script at $(date)" >> "$LOG_FILE"


    if [[ ! -f "$script_path" ]]; then
        echo "ERROR: $script_path not found. Skipping." >> "$LOG_FILE"
        continue
    fi


    if ! bash "$script_path" >> "$LOG_FILE" 2>&1; then
        echo "ERROR: $script failed. Exiting." >> "$LOG_FILE"
        exit 1
    fi


    echo "Finished $script at $(date)" >> "$LOG_FILE"
    echo "------------------------------------------------------------" >> "$LOG_FILE"
done


echo "INFOCALC pipeline completed at $(date)" >> "$LOG_FILE"









