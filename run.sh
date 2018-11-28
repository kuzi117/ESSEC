#!/bin/sh

#SBATCH --account=def-sutton
#SBATCH --error=slurm-%j-%n-%a.err
#SBATCH --output=slurm-%j-%n-%a.out
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=0-24:00

module load java/1.8.0_121

source activate 651
'./tasks_'"$SLURM_ARRAY_TASK_ID"'.sh'
