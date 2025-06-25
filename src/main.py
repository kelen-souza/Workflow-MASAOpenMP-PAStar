from pycompss.api.api import compss_wait_on
from apps import *
import argparse
import os



def main(input_alignment_file, base_work_dir):
    sequence_dir = create_dir(os.path.join(base_work_dir, "sequences"))
    split_files_f = split_sequences(input_alignment_file, sequence_dir)
    split_files = compss_wait_on(split_files_f)
    pairs_rootdir = create_dir(os.path.join(base_work_dir, "pair_sequences"))
    pairs_rootdir = compss_wait_on(pairs_rootdir)
    results = list()
    for i in range(len(split_files)):
        for j in range(i + 1, len(split_files)):
            seq1 = split_files[i]
            seq2 = split_files[j]
            pair_id = seq1.split(".")[-2] + "_" + seq2.split(".")[-2]
            pair_dir = create_dir(os.path.join(pairs_rootdir, pair_id))
            align_out="alignment.00.txt"
            seq1f, seq2f, alignf = compss_wait_on(prepare_for_masa(pair_dir,seq1, seq2,align_out, os.path.join(base_work_dir, "sequences")))
            masa(pair_dir, 1, seq1f, seq2f, alignf)
            results.append(get_metrics(pair_dir, alignf))

    results = compss_wait_on(results)
    for res in results:
        print(res)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", type=str, required=True, help="Arquivo multifasta de entrada")
    parser.add_argument("-w", "--workdir", type=str, required=False, default=os.getcwd(), help="Diretório de trabalho")
    args = parser.parse_args()

    main(args.input, args.workdir)
