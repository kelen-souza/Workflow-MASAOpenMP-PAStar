from pycompss.api.api import compss_wait_on, compss_barrier
from apps import *
import argparse
import os



def main(input_alignment_file, base_work_dir, max_sequences=5):
    align_out="alignment.00.txt"
    sequence_dir = compss_wait_on(create_dir(os.path.join(base_work_dir, "sequences")))
    split_files = compss_wait_on(split_sequences(input_alignment_file, sequence_dir))
    pairs_rootdir = compss_wait_on(create_dir(os.path.join(base_work_dir, "pair_sequences")))
    metrics = list()
    folders_to_create = list()
    for i in range(len(split_files)):
        for j in range(i + 1, len(split_files)):
            seq1 = split_files[i]
            seq2 = split_files[j]
            pair_id = seq1.split(".")[-2] + "_" + seq2.split(".")[-2]
            folders_to_create.append(create_dir(os.path.join(pairs_rootdir, pair_id)))
    #sync after creating all the folders to avoid error on pycompss
    compss_wait_on(folders_to_create)
    for i in range(len(split_files)):
        for j in range(i + 1, len(split_files)):
            seq1 = split_files[i]
            seq2 = split_files[j]
            pair_id = seq1.split(".")[-2] + "_" + seq2.split(".")[-2]
            pair_dir = os.path.join(pairs_rootdir, pair_id)
            seq1f = os.path.join(sequence_dir, seq1)
            seq2f = os.path.join(sequence_dir, seq2)
            alignf = os.path.join(pair_dir, align_out)
            # print(pair_id)
            # print(seq1f)
            # print(seq2f)
            # print(alignf)
            masa(pair_dir, 1, seq1f, seq2f, alignf)
            metrics.append(get_metrics(pair_dir, alignf, seq1, seq2))
    joined_sequences = os.path.join(base_work_dir, "selected_sequences.fasta")
    # compss_wait_on(metrics)
    compss_wait_on(filter_sequences(metrics, sequence_dir, max_sequences,joined_sequences))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", type=str, required=True, help="Arquivo multifasta de entrada")
    parser.add_argument("-w", "--workdir", type=str, required=False, default=os.getcwd(), help="Diretório de trabalho")
    args = parser.parse_args()

    main(args.input, args.workdir)
