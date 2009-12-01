import os, sys
from openeye.oechem import *
from openeye.oezap import *
from openeye.oegrid import *

def Output(mol, apot, showAtomTable):
  #print "Title: %s"%mol.GetTitle()
  #if showAtomTable:
  #    OEThrow.Info("Atom potentials");
  #    OEThrow.Info("Index  Elem    Charge     Potential");

  energy=0.0

  for atom in mol.GetAtoms():
      res = OEAtomGetResidue(atom)
      energy += atom.GetPartialCharge()*apot[atom.GetIdx()]
      if showAtomTable:
          print "%-6d %6d %3s %10.3f %10.3f %10.3f %10.3f"%(atom.GetIdx(),
                  res.GetSerialNumber(),
                  OEGetAtomicSymbol(atom.GetAtomicNum()),
                  atom.GetRadius(),
                  atom.GetFormalCharge(),
                  atom.GetPartialCharge(),
                  apot[atom.GetIdx()])

          #print "Sum of {Potential * Charge over all atoms * 0.5} in kT = %f\n" % (0.5*energy)

def CalcAtomPotentials(itf):
    mol = OEGraphMol()

    ifs = oemolistream()
    if not ifs.open(itf.GetString("-in")):
        OEThrow.Fatal("Unable to open %s for reading" % itf.GetString("-in"))

    # OEReadMolecule(ifs,mol)

    OEReadPDBFile(ifs,mol)
    OEAssignBondiVdWRadii(mol)
    OEDetermineConnectivity(mol)
    OEFindRingAtomsAndBonds(mol)
    OEPerceiveBondOrders(mol)
    OEAssignImplicitHydrogens(mol)
    OEAssignFormalCharges(mol)
    OEAssignAromaticFlags(mol)

    if not itf.GetBool("-file_charges"):
        OEMMFFAtomTypes(mol)
        OEMMFF94PartialCharges(mol)

    zap = OEZap()  
    zap.SetMolecule(mol)
    zap.SetInnerDielectric(itf.GetFloat("-epsin"))
    zap.SetBoundarySpacing(itf.GetFloat("-boundary"))
    zap.SetGridSpacing(itf.GetFloat("-grid_spacing"))

#    grid_file = itf.GetString("-grid_file")
#    if grid_file:
#        grid = OEScalarGrid()
#        if zap.CalcPotentialGrid(grid):
#            if itf.GetBool("-mask"):
#                OEMaskGridByMolecule(grid, mol)
#            OEWriteGrid(grid_file, grid)

    showAtomTable = itf.GetBool("-atomtable")
    calcType = itf.GetString("-calc_type")
    if calcType=="default":        
        apot = OEFloatArray(mol.GetMaxAtomIdx())
        zap.CalcAtomPotentials(apot)
        Output(mol, apot, showAtomTable)

    elif calcType == "solvent_only":
        apot = OEFloatArray(mol.GetMaxAtomIdx())
        zap.CalcAtomPotentials(apot)

        apot2 = OEFloatArray(mol.GetMaxAtomIdx())
        zap.SetOuterDielectric(zap.GetInnerDielectric())
        zap.CalcAtomPotentials(apot2)

        # find the differences
        for atom in mol.GetAtoms():
            idx=atom.GetIdx()
            apot[idx] -= apot2[idx]

        Output(mol, apot, showAtomTable)

    elif calcType == "remove_self":
        apot = OEFloatArray(mol.GetMaxAtomIdx())
        zap.CalcAtomPotentials(apot, True)
        Output(mol, apot, showAtomTable)

    elif calcType == "coulombic":
        epsin = itf.GetFloat("-epsin")
        x = OECoulombicSelfEnergy(mol, epsin)
        print "Coulombic Assembly Energy"
        print "  = Sum of {Potential * Charge over all atoms * 0.5} in kT = %f"%x
        apot = OEFloatArray(mol.GetMaxAtomIdx())
        OECoulombicAtomPotentials(mol, epsin, apot)
        Output(mol, apot, showAtomTable)

    return 0

def SetupInterface(itf, InterfaceData):
    OEConfigure(itf, InterfaceData)
    if OECheckHelp(itf, sys.argv):
        return False
    if not OEParseCommandLine(itf, sys.argv):
        return False
    return True

def main(InterfaceData):
    itf=OEInterface()
    if not SetupInterface(itf, InterfaceData):
        return 1

    return CalcAtomPotentials(itf)

InterfaceData="""
#zap_atompot interface definition

!PARAMETER -in
!TYPE string
!BRIEF Input molecule file.
!REQUIRED true
!KEYLESS 1
!END

!PARAMETER -file_charges
!TYPE bool
!DEFAULT false
!BRIEF Use partial charges from input file rather than calculating with MMFF.
!END

!PARAMETER -calc_type
!TYPE string
!DEFAULT default
!LEGAL_VALUE default 
!LEGAL_VALUE solvent_only 
!LEGAL_VALUE remove_self 
!LEGAL_VALUE coulombic 
!LEGAL_VALUE breakdown
!BRIEF Choose type of atom potentials to calculate
!END

!PARAMETER -atomtable
!TYPE bool
!DEFAULT false
!BRIEF Output a table of atom potentials
!END

!PARAMETER -epsin
!TYPE float
!BRIEF Inner dielectric
!DEFAULT 1.0
!LEGAL_RANGE 0.0 100.0
!END

!PARAMETER -grid_spacing
!TYPE float
!DEFAULT 0.5
!BRIEF Spacing between grid points (Angstroms)
!LEGAL_RANGE 0.1 2.0
!END

!PARAMETER -boundary
!ALIAS -buffer
!TYPE float
!DEFAULT 2.0
!BRIEF Extra buffer outside extents of molecule.
!LEGAL_RANGE 0.1 10.0
!END

!PARAMETER -mask
!TYPE bool
!DEFAULT false
!BRIEF Mask potential grid by the molecule
!END
"""

if __name__ == "__main__":
    sys.exit(main(InterfaceData))
#!PARAMETER -grid_file
#!TYPE string
#!BRIEF Grid file to be saved
#!DEFAULT ''
#!END
#
