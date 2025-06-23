from pycompss.api.api import compss_wait_on
from apps import *
import argparse, os


def main(alignment_file, work_dir):
    sequence_dir = create_dir(os.path.join(work_dir, "sequences"))
    r_split = split_sequences(alignment_file, sequence_dir)
    r_metrics = list()
    for i in range (0, len(r_split)):
        for j in range(i+1, len(r_split)):
            dir_name = r_split[i].split(".")[-2] + "_" + r_split[j].split(".")[-2]
            dir = create_dir(os.path.join(work_dir, dir_name))
            alignment_file = os.path.join(dir, "aligment00.txt")
            masa(".", "1", os.path.join(sequence_dir, r_split[i]), os.path.join(sequence_dir, r_split[j]),alignment_file)
            r_metrics.append(get_metrics(alignment_file))

    compss_wait_on(r_metrics)
    for m in r_metrics:
        print(m)




if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", type=str, required=True)
    parser.add_argument("-w","--workdir", type=str, required=False, default=os.getcwd())
    args = parser.parse_args()
    main()