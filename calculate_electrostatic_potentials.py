#!/usr/bin/env python

import os, sys
from openeye.oechem import *
from openeye.oezap import *
from openeye.oegrid import *
from openeye.oespicoli import *

def main(argv = [__name__]):

    if len(argv) != 2:
        OEThrow.Usage("%s <molfile>" % argv[0])

    ifs = oemolistream()
    if not ifs.open(argv[1]):
        OEThrow.Fatal("Unable to open %s for reading" % argv[1])

    mol = OEGraphMol()
    OEReadMolecule(ifs, mol)  
    OEAssignBondiVdWRadii(mol)
    OEMMFFAtomTypes(mol)
    OEMMFF94PartialCharges(mol)

    epsin = 1.0
    grid = OEScalarGrid()
    #OEMakeMolecularGaussianGrid(grid, mol, 0.5)

    atom_asa = OEFloatArray(mol.GetMaxAtomIdx())
    atom_pot = OEFloatArray(mol.GetMaxAtomIdx())
    area = OEArea()
    area.GetArea(mol, atom_asa)

    zap = OEZap()
    zap.SetInnerDielectric(epsin)
    zap.SetMolecule(mol)
    zap.SetGridSpacing(0.5)
    zap.CalcPotentialGrid(grid)
    zap.CalcAtomPotentials(atom_pot)

    surf = OESurface()
    OEMakeAccessibleSurface(surf, mol)
    #OEMakeSurfaceFromGrid(surf, grid, 0.5)
    OESetSurfacePotentials(surf, grid)

    OEPerceiveResidues(mol, OEPreserveResInfo_All)
    hv = OEHierView(mol)

    atom_to_vertices = {}

    for i in range(0, surf.GetNumVertices()-1):
        atom = mol.GetAtom(OEHasAtomIdx(surf.GetAtomsElement(i)))

        try:
            atom_to_vertices.keys().index(atom.GetIdx())
        except ValueError:
            atom_to_vertices[atom.GetIdx()] = []

        atom_to_vertices[atom.GetIdx()].append(i)

    print '# ' + ', '.join(['Chain ID',
                            'Residue code',
                            'Residue name',
                            'Atom code',
                            'Atom name',
                            'Formal charge',
                            'Partial charge',
                            'ASA',
                            'Atom potential',
                            'ASA potential'])

    for chain in hv.GetChains():
        for frag in chain.GetFragments():
            for res in frag.GetResidues():
                atm_cnt = 0
                res_asa = 0.0
                res_pot = 0.0

                for atom in res.GetAtoms():
                    vcnt = 0
                    asa_pot = 0.0
                    res_asa += atom_asa[atom.GetIdx()]

#                    for i in range(0, surf.GetNumVertices()-1):
#                        atm = mol.GetAtom(OEHasAtomIdx(surf.GetAtomsElement(i)))
#                        if atom.GetIdx() == atm.GetIdx():
#                            vcnt += 1
#                            #asa_pot += vpot[i]
#                            asa_pot += surf.GetPotentialElement(i)

                    try:
                        for vi in atom_to_vertices[atom.GetIdx()]:
                            vcnt += 1
                            asa_pot += surf.GetPotentialElement(vi)
                    except KeyError:
                        pass

                    if vcnt != 0:
                        asa_pot = asa_pot / vcnt
                        res_pot += asa_pot
                        atm_cnt += 1

                    print ', '.join([chain.GetChainID(),
                                    str(res.GetResidueNumber()),
                                    res.GetResidueName(),
                                    str(atom.GetIdx()),
                                    atom.GetName(),
                                    str(atom.GetFormalCharge()),
                                    str(atom.GetPartialCharge()),
                                    str(atom_asa[atom.GetIdx()]),
                                    str(atom_pot[atom.GetIdx()]),
                                    str(asa_pot)])

#                    print "%5s %5d %5s %5d %5s %6.2f %6.2f %10.2f %10.2f %10.2f" % (chain.GetChainID(),
#                                                                                    res.GetResidueNumber(),
#                                                                                    res.GetResidueName(),
#                                                                                    atom.GetIdx(),
#                                                                                    atom.GetName(),
#                                                                                    atom.GetFormalCharge(),
#                                                                                    atom.GetPartialCharge(),
#                                                                                    atom_asa[atom.GetIdx()],
#                                                                                    atom_pot[atom.GetIdx()],
#                                                                                    asa_pot)

#                if atm_cnt != 0:
#                    res_pot /= atm_cnt
#
#                print "%5s %5d %d %5s %6.2f %6.2f" % (chain.GetChainID(),
#                                                    frag.GetFragmentNumber(),
#                                                    res.GetResidueNumber(),
#                                                    res.GetResidueName(),
#                                                    res_asa,
#                                                    res_pot)

    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))

