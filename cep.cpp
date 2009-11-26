#include "openeye.h"

#include "oeplatform.h"
#include "oesystem.h"
#include "oechem.h"
#include "oespicoli.h"
#include "openeye.h"
#include "oezap.h"
#include "oebio.h"

using namespace OESpicoli;
using namespace OEChem;
using namespace OESystem;
using namespace OEPlatform;
using namespace OEPB;
using namespace OEBio;
using namespace std;

int main(int argc, char *argv[])
{  
    if (argc!=2)
        OEThrow.Usage("%s <molfile>", argv[0]);

    oemolistream ifs(argv[1]);

    OEGraphMol mol;
    //OEReadMolecule(ifs, mol);
    OEReadPDBFile(ifs, mol, OEPDBIFlag::ALL);
    OEAssignBondiVdWRadii(mol);    
    OEMMFFAtomTypes(mol);
    OEMMFF94PartialCharges(mol);

    float epsin = 1.0;
    float *atom_asa = new float[mol.GetMaxAtomIdx()];
    float *atom_pot = new float[mol.GetMaxAtomIdx()];

    OEArea area;
    area.GetArea(mol, atom_asa);

    OEScalarGrid grid;
    //OEMakeMolecularGaussianGrid(grid, mol, 0.5);

    OEZap zap;
    zap.SetInnerDielectric(epsin);
    zap.SetMolecule(mol);
    zap.CalcPotentialGrid(grid);
    zap.CalcAtomPotentials(atom_pot);

    OESurface surf;
    OEMakeAccessibleSurface(surf, mol);
    OESetSurfacePotentials(surf, grid);

    OEPerceiveResidues(mol, OEPreserveResInfo::All);
    OEHierView hv(mol);

    map< int, vector<int> > atom_to_vertices;

    OEAtomBase *atom;

    for(unsigned int i = 0; i < surf.GetNumVertices() - 1; ++i) {
        atom = mol.GetAtom(OEHasAtomIdx(surf.GetAtomsElement(i)));

        if (atom_to_vertices.count(atom->GetIdx())) {
            atom_to_vertices[atom->GetIdx()].push_back(i);
        } else {
            vector<int> v;
            atom_to_vertices.insert(map< int, vector<int> >::value_type(atom->GetIdx(), v));
        }
    }

    cout << "# Chain ID, Residue code, Residue name, "
         << "Atom code, Atom name, Formal charge, Partial charge, "
         << "ASA, Atom potential, ASA potential" << endl;

    for (OEIter<OEHierChain> chain = hv.GetChains(); chain; ++chain) {
        for (OEIter<OEHierFragment> fragment = chain->GetFragments(); fragment; ++fragment) {
            for (OEIter<OEHierResidue> residue = fragment->GetResidues(); residue; ++residue) {
                for (OEIter<OEAtomBase> atom = residue->GetAtoms(); atom; ++atom) {

                    float asa_pot = 0.0;
                    map< int, vector<int> >::iterator it1 = atom_to_vertices.find(atom->GetIdx());

                    if (it1 != atom_to_vertices.end()) {
                        vector<int> vec = atom_to_vertices[atom->GetIdx()];

                        for (vector<int>::iterator it2 = vec.begin(); it2 != vec.end(); ++it2) {
                            asa_pot += surf.GetPotentialElement(*it2);
                        }
                        asa_pot /= vec.size();
                    }

                    cout << chain->GetChainID()         << ", "
                         << residue->GetResidueNumber() << ", "
                         << residue->GetResidueName()   << ", "
                         << atom->GetIdx()              << ", "
                         << atom->GetName()             << ", "
                         << atom->GetFormalCharge()     << ", "
                         << atom->GetPartialCharge()    << ", "
                         << atom_asa[atom->GetIdx()]    << ", "
                         << atom_pot[atom->GetIdx()]    << ", "
                         << asa_pot << endl;
                }
            }
        }
    }

    return 0;
}
