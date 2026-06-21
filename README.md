# CBR Internship pipeline

## The pipeline is designed to include the following files:

1. split_vcf.sh:
 -	This script takes in the main .vcf.gz file as input, counts the number of variants, and divides them by 100.
 -	The header file for the subsequent.vcf.gz chunks is isolated beforehand, prior to the variant counting.
 -	This code proceeds to make temporary chunks of variants, followed by packaging them into .vcf.gz chunk files, which will be stored in the appropriate split_vcf directory. Each file will be named popname_chr(number)_xxx.vcf.gz, where xxx is a 0-padded number (like 001, 002, etc).
 -	The temp files are deleted once each .vcf.gz file is formed and packaged.
 -	In case the chunks already exist in the form of .vcf.gz files and are non-empty, the script skips splitting altogether, making it easier to resume other scripts in case of code failure or computer resource limitations.
 -	In case the temp chunks exist but not the .vcf.gz files, the packaging resumes from there without remaking the temp chunks from the top.
 -	The temp chunk directory and header.vcf files are deleted after all the .vcf.gz files are formed after splitting.
<br>

2. str_info2.sh:
 -	This script processes .str files from the .vcf.gz chunks based on the provided popmap files. 
 -	This is done with the help of a Python script vcf_to_str_big.py.
 -	Each file will be named out_popname_chr(number)_xxx.str, where xxx is the corresponding chunk number.
 -	Followed by this step is the running of the infocalc.pl script on the .str files to generate result files of the form result_popname_chr(number)_xxx.csv.
 -	These files will be stored in the respective out_str subdirectories corresponding to the popname of the .str and .csv files (SAS, EAS, EUR, AFR, and AMR).
 -	The .str files are deleted immediately after the .csv file is made to prevent memory issues.
 -	In the presence of non-empty .csv files, the processing of .str and .csv file formation is skipped, and the script only processes in the case of missing files corresponding to the .vcf.gz chunk number (001, 002, etc.) and popname.


3. validate2.sh:
 -	This script performs a validation check to see if all .str and .csv files are present for the specified popnames and regenerates any missing files.
<br>

4. mismatch_csv2.sh:
 -	This script compares all the variant IDs from the result .csv files with the variant IDs in the .vcf.gz files (after deriving them), and checks for missing variants present in the .vcf.gz but not in the result .csvs.
 -	The infocalc script is known to reject certain variants in certain cases, such as if it determines that a certain variant is common to all populations or there are missing values in the .str files that cannot help determine the informativeness of the variant.
 -	This script outputs a .txt file with all such missing variants. It has been made to compare a particular population across particular possible combinations mentioned.
<br>

5. merge_csv2.sh:
 - This script merges all the .csv files after their formation for specific popnames mentioned.
<br>

6. final2.sh:
 - This is the final script that contains the complete pipeline that needs to be executed to get the final outputs.
<br>

7. final2.sbatch:
 -	This is the SLURM script to schedule any infocalc jobs.
 -	All echoes from all the .sh scripts, part of the pipeline, are written into the infocalc.log file.
<br>

8. vcf_to_str_big.py:
 - This script processes the .str file using the .vcf.gz chunk and popmap files.
 - This script is much more efficient than vcf_to_str_big_backup.py.
<br>

8b. vcf_to_str_big_backup.py:
 - To be used if vcf_to_str_big.py is giving errors.
<br>

9. infocalc.pl:
 - The main infocalc script. Script taken from https://rosenberglab.stanford.edu/software/infocalc
<br>

## Execution:
Based on resource requirements, optimise the parameters in the .sbatch file, if u wish to execute the pipeline on a HPC cluster. You may execute only the final2.sh file in the case of regular PC specs. Please follow the comments as required to make sure all the files are named correctly, and the required files are created in the correct location.  
