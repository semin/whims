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

#    for (weights, write_fit, whole) in (((1., 0., 0., 0., 1., 0.), False, True),
#                                        ((1., 0.5, 1., 1., 1., 0.), False, True),
#                                        ((1., 1., 1., 1., 1., 0.), True, False)):
#        aln.salign(rms_cutoff=3.5, normalize_pp_scores=False,
#                rr_file='$(LIB)/as1.sim.mat', overhang=30,
#                gap_penalties_1d=(-450, -50),
#                gap_penalties_3d=(0, 3), gap_gap_score=0, gap_residue_score=0,
#                dendrogram_file='salign.tree',
#                alignment_type='tree',# If 'progresive', the tree is not
#                                    # computed and all structues will be
#                                    # aligned sequentially to the first
#                                    #ext_tree_file='1is3A_exmat.mtx', # Tree building can be avoided
#                                    # if the tree is input
#                feature_weights=weights, # For a multiple sequence alignment only
#                                        # the first feature needs to be non-zero
#                improve_alignment=True, fit=True, write_fit=write_fit,
#                write_whole_pdb=whole, output='ALIGNMENT QUALITY')

    modeller.salign.iterative_structural_align(aln)

    aln.write(file='salign.pap', alignment_format='PAP')
    aln.write(file='salign.ali', alignment_format='PIR')

if __name__ == "__main__":
    main(sys.argv[1:])
