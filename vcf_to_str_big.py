# -*- coding: utf-8 -*-
import gzip
from cyvcf2 import VCF
import csv
import argparse
import os
from multiprocessing import Pool
from functools import partial

def process_variant_chunk(variant_chunk, sample_count):
    result_chunk = []
    for chrom, pos, ref, alts, genos in variant_chunk:
        alt_str = ",".join(alts)
        variant_id = f"{chrom}:{pos}:{ref}:{alt_str}".replace("\t", "_").replace("\n", "")
        g_list = []
        for gt in genos:
            if gt is None or gt[0] is None or gt[1] is None:
                a1, a2 = "-9", "-9"
            else:
                a1 = str(gt[0] + 1) if gt[0] >= 0 else "-9"
                a2 = str(gt[1] + 1) if gt[1] >= 0 else "-9"
            g_list.append((a1, a2))
        result_chunk.append((variant_id, g_list))
    return result_chunk

def chunkify(iterable, size):
    chunk = []
    for item in iterable:
        chunk.append(item)
        if len(chunk) == size:
            yield chunk
            chunk = []
    if chunk:
        yield chunk

def main():
    parser = argparse.ArgumentParser(description="Convert VCF to STRUCTURE-format .str file")
    parser.add_argument("--vcf", required=True, help="Input VCF.gz file")
    parser.add_argument("--popmap", required=True, help="CSV file with sample to population map")
    parser.add_argument("--out", required=True, help="Output .str file path")
    args = parser.parse_args()

    # Read population map
    sample_to_pop = {}
    with open(args.popmap, newline='') as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) >= 2:
                sample_to_pop[row[0]] = row[1]

    vcf = VCF(args.vcf)
    samples = vcf.samples
    n_samples = len(samples)

    # Extract serializable data from each variant
    variant_data = []
    for variant in vcf:
        chrom = variant.CHROM
        pos = variant.POS
        ref = variant.REF
        alts = variant.ALT
        genotypes = variant.genotypes  # list of tuples
        variant_data.append((chrom, pos, ref, alts, genotypes))

    # Chunkify for parallel processing
    chunk_size = 500  # You can tune this
    variant_chunks = list(chunkify(variant_data, chunk_size))

    # Parallel processing
    with Pool(processes=72) as pool:
        result_lists = pool.map(partial(process_variant_chunk, sample_count=n_samples), variant_chunks)

    # Flatten and organize results
    variant_ids = []
    genotype_matrix = {s: [[], []] for s in samples}

    for chunk in result_lists:
        for var_id, genos in chunk:
            variant_ids.append(var_id)
            for i, (a1, a2) in enumerate(genos):
                s = samples[i]
                genotype_matrix[s][0].append(a1)
                genotype_matrix[s][1].append(a2)

    # Write STRUCTURE .str file
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        f.write("\t\t" + "\t".join(variant_ids) + "\n")
        for s in samples:
            pop = sample_to_pop.get(s, "1")
            if (s.startswith("HG") or s.startswith("NA")) and len(s) == 7:
                pop = "2"
            row1 = "\t".join(genotype_matrix[s][0])
            row2 = "\t".join(genotype_matrix[s][1])
            f.write(f"{s}\t{pop}\t{row1}\n")
            f.write(f"{s}\t{pop}\t{row2}\n")

if __name__ == "__main__":
    main()
