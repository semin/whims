#/bin/sh

# This is a script for mirroring PDB repository at EBI using lftp
# - Semin
REMOTE_SERVER="ftp.ebi.ac.uk"
REMOTE_MIRROR_DIR="/pub/databases/rcsb/pdb-remediated"
LOCAL_MIRROR_DIR="/BiO/Mirror/PDB"
LFTP="/usr/bin/lftp"
LOG="/BiO/Temp/mirror_PDB.log"

${LFTP} -c "mirror -c -e --verbose=1 --log=${LOG} --parallel=4 ftp://${REMOTE_SERVER}/${REMOTE_MIRROR_DIR} ${LOCAL_MIRROR_DIR}"
