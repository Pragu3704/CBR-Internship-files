#!/bin/bash
set -euo pipefail
trap 'echo "Error on line $LINENO"; exit 1' ERR




VCF="/gpfs/data/user/cherishma/chr21_infocalc/merged_vcf/EUR_chr21.vcf.gz"    ##Change
VCF="$(readlink -f "$VCF")"
OUTDIR="/gpfs/data/user/cherishma/chr21_infocalc/EUR_chr21/split_vcf" ##Change
TMPDIR="$OUTDIR/tmp_chunks"
HEADER="$OUTDIR/header.vcf"


# Check if splitting is needed
echo "Checking existing split VCFs in $OUTDIR..."
existing_chunks=()
while IFS= read -r line; do
    existing_chunks+=("$line")
done < <(find "$OUTDIR" -maxdepth 1 -name 'EUR_chr21_*.vcf.gz' 2>/dev/null | sort)  #Change
missing=false


if [[ ${#existing_chunks[@]} -ge 1 ]]; then
    for chunk_file in "${existing_chunks[@]}"; do
        if [[ ! -s "$chunk_file" ]]; then
            missing=true
            break
        fi
    done
    if [[ "$missing" = false ]]; then
        echo "All split VCF files already exist and are non-empty. Skipping split."
        exit 0
    else
        echo "Some split VCFs missing or empty. Re-splitting from scratch..."
    fi
else
    if [[ -f "$HEADER" && -d "$TMPDIR" && -n "$(ls -A "$TMPDIR" 2>/dev/null)" ]]; then
        echo "No split VCFs found, but header and chunk files exist. Proceeding with file creation..."
    else
        echo "No existing split VCFs found. Starting split..."


        # Create necessary directories
        mkdir -p "$OUTDIR"
        mkdir -p "$TMPDIR"


        # Count total number of variants (excluding header lines)
        echo "Counting variants in $VCF..."
        TOTAL=$(bcftools view -H "$VCF" | wc -l)
        CHUNKSIZE=$(( (TOTAL + 99) / 100 ))
        echo "Total variants: $TOTAL"
        echo "Chunk size: $CHUNKSIZE"


        # Extract header
        echo "Extracting VCF header..."
        bcftools view -h "$VCF" > "$HEADER"


        # Extract data lines and split into chunks
        echo "Splitting VCF into chunks..."
        bcftools view -H "$VCF" | split -l "$CHUNKSIZE" - "$TMPDIR/chunk_"
    fi
fi


# Combine header with each chunk and compress/index
echo "Creating split VCF files..."
i=1
for chunk in "$TMPDIR"/chunk_*; do
    suffix=$(printf "%03d" "$i")
    outvcf="$OUTDIR/EUR_chr21_${suffix}.vcf.gz"  ##Change


    cat "$HEADER" "$chunk" | bgzip -c > "$outvcf"
    tabix -p vcf "$outvcf"
    rm -f "$chunk" #Deletes chunk after .vcf.gz is formed


    i=$((i + 1))
done


# Cleanup
echo "Cleaning up temporary files..."
rm -f "$HEADER"
rm -rf "$TMPDIR"


echo "All done. Split VCFs are in $OUTDIR"








