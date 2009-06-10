#/bin/sh

# This is a script for mirroring DSSP repository at EBI using lftp
# - Semin
REMOTE_SERVER="ftp.ebi.ac.uk"
REMOTE_MIRROR_DIR="/pub/databases/dssp"
LOCAL_MIRROR_DIR="/BiO/Mirror/DSSP"
LFTP="/usr/bin/lftp"
LOG="/BiO/Temp/mirror_DSSP.log"

${LFTP} -c "mirror -c -e --verbose=3 --log=${LOG} --parallel=4 ftp://${REMOTE_SERVER}/${REMOTE_MIRROR_DIR} ${LOCAL_MIRROR_DIR}"
