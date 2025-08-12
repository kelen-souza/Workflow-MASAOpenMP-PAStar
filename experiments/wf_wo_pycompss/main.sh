#!/bin/bash
#SBATCH --nodes=1                               # Número de Nós
#SBATCH --ntasks-per-node=1                     # Número de tarefas por Nó
#SBATCH --ntasks=1                              # Número de tarefas
#SBATCH -p sequana_cpu_dev                      # Fila (partition) a ser utilizada
#SBATCH --time=00:20:00                         # Tempo máximo de execução
#SBATCH -J masa_test                            # Nome do job
#SBATCH --exclusive
#SBATCH -o slurm_%j.out                         # Output padrão do SLURM
#SBATCH -e slurm_%j.err                         # Output padrão do SLURM

#export OMP_NUM_THREADS=1
module load gcc/9.3_sequana
module load boost/1.87.0_gnu+openmpi-4.1.4_sequana
module load masa-openmp/1.0.1.1024_sequana
module load anaconda3/2024.02_sequana
eval "$(conda shell.bash hook)"
conda activate /scratch/cenapadrjsd/rafael.terra2/conda_envs/parsl_test

export PATH=$PATH:/scratch/cenapadrjsd/app/pa-star2/bin/
# Muda para o diretório do script
cd /scratch/cenapadrjsd/rafael.terra2/Workflow-MASAOpenMP-PAStar/experiments/wf_wo_pycompss
# Diretório de trabalho
WORKING_DIR="/scratch/cenapadrjsd/rafael.terra2/Workflow-MASAOpenMP-PAStar/experiments/saida"

SEQ_FILE="/scratch/cenapadrjsd/rafael.terra2/Workflow-MASAOpenMP-PAStar/experiments/C_denv1.fasta"        # Arquivo no formato multifasta
SEQS_PATH="${WORKING_DIR}/sequences"          # Pasta das sequências individuais
PAIRS_PATH="${WORKING_DIR}/pair_sequences"     # Pasta com pares de sequências

# Remove a pasta das sequências individuais e cria uma nova
rm -rf "${SEQS_PATH}"
mkdir -p "${SEQS_PATH}"

# Mesma coisa para a pasta de pares
rm -rf "${PAIRS_PATH}"
mkdir -p "${PAIRS_PATH}"

python ./split_sequences.py "${SEQ_FILE}" "${SEQS_PATH}" # Divide as sequências


SEQS=($(ls "${SEQS_PATH}")) # Utiliza as sequências separadas pelo script (X sequências, cada uma em um .fasta)

declare -a pid_list # declara um array vazio para os p_ids do masa (utilizado para sincronizar com o filtro)

echo "Executando masa nos pares"
# Realiza a combinação par-a-par das sequencias
for ((i = 0; i < ${#SEQS[@]}; i++)); do
    for ((j = i + 1; j < ${#SEQS[@]}; j++)); do
        # Seleciona dois arquivos do vetor de sequências
        seq1="${SEQS_PATH}/${SEQS[i]}"
        seq2="${SEQS_PATH}/${SEQS[j]}"
        seq1_name=$(echo "${SEQS[i]}" | awk -F '.' '{OFS="."; NF--; print}')
        seq2_name=$(echo "${SEQS[j]}" | awk -F '.' '{OFS="."; NF--; print}')
        OUTDIR="${PAIRS_PATH}/${seq1_name}_${seq2_name}"
        mkdir -p "${OUTDIR}"
        # Verifica se os arquivos existem
        [ ! -f "${seq1}" ] && echo "Arquivo seq1 não encontrado: ${seq1}" && exit 1
        [ ! -f "${seq2}" ] && echo "Arquivo seq2 não encontrado: ${seq2}" && exit 1
        # Limpa a execução antiga e executa o MASA
        rm -rf "${OUTDIR}"
        mkdir -p "${OUTDIR}"
        OMP_NUM_THREADS=1 masa-openmp --work-dir "${OUTDIR}" "${seq1}" "${seq2}" &
        pid_list+=($!)
    done
done

echo "Esperando MASAs"

# Espera a conclusão de todos os MASA
if [ ${#pid_list[@]} -gt 0 ]; then
    wait "${pid_list[@]}"
fi

echo "Filtrando Sequências"
similar=0                 # 0 -> mais divergentes, 1-> mais similares
max_seqs=5                # Número máximo de sequências
JOINED_SEQS="${WORKING_DIR}/joined.fasta" # Arquivo fasta das sequências selecionadas
rm ${JOINED_SEQS}
# Realiza a coleta das métricas e seleção das sequências
python ./filter.py "${PAIRS_PATH}" "${SEQS_PATH}" "${similar}" "${max_seqs}" "${JOINED_SEQS}"

OUT_PASTAR="${WORKING_DIR}/msa.fasta"    # Arquivo fasta com o MSA

echo "Executando o PA-Star"

# Executa o PA-Star
msa_pastar -f "${OUT_PASTAR}" -t 48 "${JOINED_SEQS}"
