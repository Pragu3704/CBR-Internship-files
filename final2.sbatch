#!/bin/bash
#SBATCH --job-name=infocalc_EUR_chr21
#SBATCH --output=infocalc_EUR_chr21_%j.log
#SBATCH --error=infocalc_EUR_chr21_%j.err
#SBATCH --partition=cbr_q_large
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=72




set -euo pipefail


exec > infocalc.log 2>&1




bash /gpfs/data/user/pragathi/chr21_infocalc/EUR_chr21/final2.sh  ##Or final2.sh depnding on type of code ur running


echo "====Finished piepline==="









