#/bin/sh

# This is a script for mirroring PDB repository at EBI using lftp
# - Semin
REMOTE_SERVER="ftp.ebi.ac.uk"
REMOTE_MIRROR_DIR="/pub/databases/integr8"
LOCAL_MIRROR_DIR="/BiO/Mirror/Integr8"
LFTP="/usr/bin/lftp"
LOG="/BiO/Temp/mirror_Integr8.log"

${LFTP} -c "mirror -c -e --verbose=3 --log=${LOG} --parallel=4 ftp://${REMOTE_SERVER}/${REMOTE_MIRROR_DIR} ${LOCAL_MIRROR_DIR}"
