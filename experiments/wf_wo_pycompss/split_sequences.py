import os, sys
from Bio import SeqIO

def split_sequences(multifasta_file, sequence_dir):
     """Split a multifasta file into N fasta files, with one sequence each

     Args:
         multifasta_file (str): multifasta file containning the sequences

     Returns:
         dict: List of all the sequences files
     """
     records = list(SeqIO.parse(multifasta_file, "fasta"))
     record_ids = list()
     for r in records:
          if len(r.id) > 8:
               seq_id = r.id[:8]
          else:
               seq_id = r.id
          out_file = os.path.join(sequence_dir, f"{seq_id}.fasta")
          SeqIO.write(r, out_file, "fasta")
          record_ids.append(f"{seq_id}.fasta")
     return record_ids


if __name__ == "__main__":
    if len(sys.argv) <= 1:
        print('argumentos insuficientes')
        sys.exit()
    multifasta_file = sys.argv[1]
    sequence_dir = sys.argv[2]