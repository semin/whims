#!/usr/bin/env python

# Illustrates the SALIGN multiple structure/sequence alignment
import sys
from modeller import *
import modeller.salign

def main(argv):
    if len(argv) < 2:
        print
        print "Usage: python salign.py structure1.pdb structure2.pdb ..."
        print
        sys.exit(2)

    #log.minimal()
    log.none()
    env = environ()
    env.io.atom_files_directory = ['.']
    aln = alignment(env)

    for code in argv:
        mdl = model(env)
        mdl.read(file=code, model_segment=('FIRST:@', 'END:'))
        aln.append_model(mdl, atom_files=code, align_codes=code)

    modeller.salign.iterative_structural_align(aln)
    aln.write(file='salign.ali', alignment_format='PIR')

if __name__ == "__main__":
    main(sys.argv[1:])
