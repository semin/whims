#/bin/sh

# This is a script for mirroring PDB repository at EBI using lftp
# - Semin
REMOTE_SERVER="dalek.nibio.go.jp"
REMOTE_MIRROR_DIR="/homstrad/data"
LOCAL_MIRROR_DIR="/BiO/Mirror/HOMSTRAD/data"
LFTP="/usr/bin/lftp"
LOG="/BiO/Temp/mirror_HOMSTRAD.log"

${LFTP} -c "mirror -c -e --verbose=3 --parallel=4 --log=${LOG} ftp://${REMOTE_SERVER}/${REMOTE_MIRROR_DIR} ${LOCAL_MIRROR_DIR}"
