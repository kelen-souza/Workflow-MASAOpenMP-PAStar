#!/bin/bash
#SBATCH --nodes=1            			#Número de Nós
#SBATCH --ntasks-per-node=1  			#Número de tarefas por Nó
#SBATCH --ntasks=1           			#Número de tarefas
#SBATCH --cpus-per-task=1   			#Número de threads por tarefa
#SBATCH -p sequana_cpu_dev   			#Fila (partition) a ser utilizada
#SBATCH --time=00:05:00			    	#Tempo máximo de execução
#SBATCH -J masa_glg_1t_seq12345   		#Nome do job (job name) (EDITAR)
#SBATCH --exclusive          			#Uso do nó de forma exclusiva

# Carrega os módulos necessários
module load sequana/current
module load masa-openmp/1.0.1.1024_sequana

# Diretórios de entrada e saída
DIR_INPUT="/scratch/cenapadrjsd/kelen.souza/masaopenmp/benchmark-split"
DIR_OUTPUT="/scratch/cenapadrjsd/kelen.souza/masaopenmp/teste"

cd "$DIR_INPUT"

# Arquivos FASTA (EDITAR)
INPUTS=("glg-seq1-glu_hpyl.fasta" "glg-seq2-mg39733.fasta" "glg-seq3-scmse1g.fasta" "glg-seq4-glu_mlepr.fasta" "glg-seq5-glu_pylor.fasta")

EXEC="masa-openmp"

# Diretório de trabalho base
WORK_DIR_BASE="$DIR_OUTPUT/work_${SLURM_JOB_ID}"
mkdir -p "$WORK_DIR_BASE"

# Loop de pares
for ((i = 1; i < ${#INPUTS[@]}; i++)); do
    for ((j = i + 1; j <= ${#INPUTS[@]}; j++)); do
        SEQ1="${INPUTS[$i-1]}"
        SEQ2="${INPUTS[$j-1]}"
        WORK_DIR="$WORK_DIR_BASE/work_run${i}-${j}"
        mkdir -p "$WORK_DIR"

        echo "Alinhando $SEQ1 x $SEQ2..."

       /usr/bin/time -f "Tempo de execução: %e segundos" \
    srun $EXEC --work-dir="$WORK_DIR" -t "$SLURM_CPUS_PER_TASK" "$DIR_INPUT/$SEQ1" "$DIR_INPUT/$SEQ2"

        ALIGN_FILE="$WORK_DIR/alignment.00.txt"

        if [[ -f "$ALIGN_FILE" ]]; then
            TOTAL_SCORE=$(grep -i "Total score" "$ALIGN_FILE" | awk '{print $3}')

	    # Extrai todos os comprimentos entre parênteses após "Query" e "Sbjct"
	    LENGTHS=($(grep -E "^(Query|Sbjct):" "$ALIGN_FILE" | grep -oP '\(\K\d+(?=\))'))

            if [[ ${#LENGTHS[@]} -ge 2 && -n "$TOTAL_SCORE" ]]; then
                MIN_LEN=${LENGTHS[0]}
                [[ ${LENGTHS[1]} -lt $MIN_LEN ]] && MIN_LEN=${LENGTHS[1]}

                if [[ "$MIN_LEN" -ne 0 ]]; then
                    RAW_SIM=$(echo "scale=6; ($TOTAL_SCORE / $MIN_LEN) * 100" | bc)
		    SIMILARIDADE=$(printf "%.2f" "$RAW_SIM")
                    RESULT_FILE="$WORK_DIR/similaridade.txt"
                    {
			printf "Par: %s x %s\n\n" "$SEQ1" "$SEQ2"
                        printf "Total Score: %s\n\n" "$TOTAL_SCORE"
                        printf "Menor Sequencia: %s\n\n" "$MIN_LEN"
                        printf "Similaridade: %s %%\n\n" "$SIMILARIDADE"
                    } > "$RESULT_FILE"

                    printf "Similaridade salva: %s%% (%s)\n\n\n" "$SIMILARIDADE" "$WORK_DIR"
                else
                    echo "Menor sequência = 0 em $ALIGN_FILE"
                fi
            else
                echo "Dados incompletos em $ALIGN_FILE"
            fi
        else
            echo "alignment.00.txt não encontrado em $WORK_DIR"
        fi
    done
done

