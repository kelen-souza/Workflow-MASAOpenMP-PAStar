#!/bin/bash
#SBATCH --nodes=1                         #Número de Nós
#SBATCH --ntasks-per-node=1               #Número de tarefas por Nó
#SBATCH --ntasks=1                        #Número de tarefas
#SBATCH --cpus-per-task=48                #Número de threads por tarefa
#SBATCH -p sequana_cpu_dev                #Fila/partition a ser utilizada 
#SBATCH --time=00:20:00                   #Tempo máximo de execução
#SBATCH -J filtro_glg_pastar2             #Nome do job (EDITAR)
#SBATCH --exclusive                       #Uso do Nó de forma exclusiva
#SBATCH -o slurm_%j.out                   #Output padrão do SLURM

# Carrega os módulos necessários
module load gcc/9.3_sequana
module load boost/1.87.0_gnu+openmpi-4.1.4_sequana

# Slurm_Job_ID do job anterior com os alinhamentos de sequências a serem filtradas 
JOB_REF=11353647   #(EDITAR)

# Limite mínimo de similaridade para filtrar as sequências (EDITAR)
SIMILARIDADE_MINIMA=1.5

# Diretórios base para entrada e saída
BASE_DIR="/scratch/cenapadrjsd/kelen.souza/masaopenmp/teste/work_${JOB_REF}"
DIR_FASTAS="/scratch/cenapadrjsd/kelen.souza/masaopenmp/benchmark-split"
DIR_OUTPUT="/scratch/cenapadrjsd/kelen.souza/masaopenmp/teste/resultado_filtro_pastar2${SLURM_JOB_ID}"
ALIGNMENT_OUTPUT="${DIR_OUTPUT}/masa_filtro_pastar2_${SLURM_JOB_ID}.out"

# Criar diretório de saída caso não exista
mkdir -p "$DIR_OUTPUT"

echo "- Identificando sequências com similaridade ≥ ${SIMILARIDADE_MINIMA} ..."

# Cria um arquivo temporário para armazenar sequências válidas
VALIDAS_TMP=$(mktemp)

# Ativa nullglob para evitar problemas se não houver arquivos correspondentes
shopt -s nullglob

# Percorre todos os arquivos de similaridade nos subdiretórios work_run*
for file in "$BASE_DIR"/work_run*/similaridade.txt; do
    # Extrai nomes das sequências e valor de similaridade do arquivo
    SEQ1=$(grep "^Par:" "$file" | awk '{print $2}' | sed 's/.fasta//')
    SEQ2=$(grep "^Par:" "$file" | awk '{print $4}' | sed 's/.fasta//')
    SIMILARIDADE=$(grep "^Similaridade:" "$file" | awk '{print $2}' | tr ',' '.' | tr -d '%')

    # Compara similaridade com o limite mínimo usando bc
    if (( $(echo "$SIMILARIDADE >= $SIMILARIDADE_MINIMA" | bc -l) )); then
        # Log do par de sequências aceito
        echo "- Par com similaridade ≥ ${SIMILARIDADE_MINIMA}%: $SEQ1 x $SEQ2"
        # Armazena nomes para a lista final
        echo "$SEQ1" >> "$VALIDAS_TMP"
        echo "$SEQ2" >> "$VALIDAS_TMP"
    fi
done

# Desativa nullglob para não afetar outras partes do script
shopt -u nullglob

# Remove nomes duplicados e salva no arquivo final
sort "$VALIDAS_TMP" | uniq > "$DIR_OUTPUT/sequencias_validas.txt"
# Remove arquivo temporário
rm "$VALIDAS_TMP"

# Conta quantas sequências válidas foram encontradas
TOTAL=$(wc -l < "$DIR_OUTPUT/sequencias_validas.txt")
echo

# Só executa alinhamento se houver pelo menos 3 sequências válidas
if (( TOTAL >= 3 )); then
    echo "- Sequências válidas: $TOTAL"
    echo "- Copiando arquivos FASTA para diretório temporário..."

    # Cria arquivo FASTA de entrada para o PA-Star2
    INPUT_FASTA="$DIR_OUTPUT/pastar2_input.fasta"
    OUTPUT_FASTA="$DIR_OUTPUT/pastar2_output.fasta"
    > "$INPUT_FASTA"  # garante que o arquivo começa vazio

    # Para cada sequência válida, concatena seu arquivo fasta no arquivo de input
    while IFS= read -r SEQ_NAME; do
        FASTA_ORIG="$DIR_FASTAS/${SEQ_NAME}.fasta"
        if [[ -f "$FASTA_ORIG" ]]; then
            cat "$FASTA_ORIG" >> "$INPUT_FASTA"
        else
            echo "- Arquivo não encontrado: $FASTA_ORIG"
        fi
    done < "$DIR_OUTPUT/sequencias_validas.txt"

    # Log com informações do job
    echo "Job name: $SLURM_JOB_NAME"
    echo "Threads: $SLURM_CPUS_PER_TASK"
    echo "- Executando PA-Star2 (msa_pastar)..."

    # Executa o PA-Star2 com o srun e monitora tempo e recursos usados
    # Output do alinhamento vai para ALIGNMENT_OUTPUT
    /usr/bin/time -v srun /scratch/cenapadrjsd/app/pa-star2/bin/msa_pastar \
        -t "$SLURM_CPUS_PER_TASK" -f "$INPUT_FASTA" "$INPUT_FASTA" > "$ALIGNMENT_OUTPUT" 2>&1
    
    # Copia o resultado do alinhamento para um arquivo .fasta
    if [ -f "$INPUT_FASTA.aln" ]; then
        cp "$INPUT_FASTA.aln" "$OUTPUT_FASTA"
        echo "- Resultado do alinhamento salvo em: $OUTPUT_FASTA"
    fi

    echo "- Execução do PA-Star2 concluída!"
    echo "- Resultados do alinhamento salvos em: $ALIGNMENT_OUTPUT"
else
    # Caso não haja sequências suficientes, apenas loga e termina
    echo "- Menos de 3 sequências válidas. Nenhum alinhamento múltiplo será executado."
fi