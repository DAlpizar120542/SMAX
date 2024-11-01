#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <NFS-server-FQDN> <Generic_volume_path> <Smarta_volume_path> <UID> <GID> [<NFS-version>]"
    exit 1
fi

MOUNT_POINT="/mnt/nfs"
NFS_SERVER=$1
GENERIC_VOLUME_PATH=${2:-""}
SMARTA_VOLUME_PATH=${3:-""}
SUITE_USER_UID=$4
SUITE_USER_GID=$5
NFS_VERSION=${6:-"4"}
NFS_PARENT="var/vols/itom"

if [ ! -d $MOUNT_POINT/${GENERIC_VOLUME_PATH} ]; then
    mkdir -p $MOUNT_POINT/${GENERIC_VOLUME_PATH}
fi

if [ ! -d $MOUNT_POINT/${SMARTA_VOLUME_PATH} ]; then
    mkdir -p $MOUNT_POINT/${SMARTA_VOLUME_PATH}
fi

declare -a arr1=(
"itsma/logging-volume"
"itsma/config-volume"
"itsma/data-volume"
)

declare -a arr2=(
"itsma/rabbitmq-infra-rabbitmq-0"
"itsma/rabbitmq-infra-rabbitmq-1"
"itsma/rabbitmq-infra-rabbitmq-2"
"itsma/itsma-smarta-sawarc-con-0"
"itsma/itsma-smarta-sawarc-con-1"
"itsma/itsma-smarta-sawarc-con-a-0"
"itsma/itsma-smarta-sawarc-con-a-1"
"itsma/itsma-smarta-saw-con-0"
"itsma/itsma-smarta-saw-con-1"
"itsma/itsma-smarta-saw-con-2"
"itsma/itsma-smarta-saw-con-3"
"itsma/itsma-smarta-saw-con-4"
"itsma/itsma-smarta-saw-con-5"
"itsma/itsma-smarta-saw-con-a-0"
"itsma/itsma-smarta-saw-con-a-1"
"itsma/itsma-smarta-saw-con-a-2"
"itsma/itsma-smarta-saw-con-a-3"
"itsma/itsma-smarta-saw-con-a-4"
"itsma/itsma-smarta-saw-con-a-5"
"itsma/itsma-smarta-sawmeta-con-0"
"itsma/itsma-smarta-sawmeta-con-1"
"itsma/itsma-smarta-sawmeta-con-a-0"
"itsma/itsma-smarta-sawmeta-con-a-1"
)

mountNFS() {
    local VOLUME_FOLDER_NAME=$1
    mount -t nfs -o nfsvers=${NFS_VERSION} ${NFS_SERVER}:/${VOLUME_FOLDER_NAME} ${MOUNT_POINT}/${VOLUME_FOLDER_NAME}
    if [ $? -eq 0 ] || [ $? -eq 32 ]; then
        echo "Successfully mount ${VOLUME_FOLDER_NAME}"
        sed -i '$a\'"$NFS_SERVER:/${VOLUME_FOLDER_NAME} $MOUNT_POINT/${VOLUME_FOLDER_NAME} nfs nfsvers=${NFS_VERSION} 0 0" /etc/fstab
    else
        echo "Could not mount ${VOLUME_FOLDER_NAME}"
        exit 1
    fi
}

make_volume() {
    local VOLUME=$1
    local VOLUME_FOLDER_NAME=$2
    pushd $(pwd)
    cd ${MOUNT_POINT}/${VOLUME_FOLDER_NAME}
    local MOUNTED_PV=${MOUNT_POINT}/${VOLUME_FOLDER_NAME}/${NFS_PARENT}/${VOLUME}
    if [ ! -d ${MOUNTED_PV} ]; then
        mkdir -p ${MOUNTED_PV}
    fi
    chown -R ${SUITE_USER_UID}:${SUITE_USER_GID} ${MOUNTED_PV}
    chmod g+w ${MOUNTED_PV}
    chmod g+s ${MOUNTED_PV}
    chmod u+w ${MOUNTED_PV}
    chmod u+s ${MOUNTED_PV}
    popd
}

mountNFS ${GENERIC_VOLUME_PATH}
mountNFS ${SMARTA_VOLUME_PATH}

for i in "${arr1[@]}"; do
    make_volume ${i} ${GENERIC_VOLUME_PATH}
done

for i in "${arr2[@]}"; do
    make_volume ${i} ${SMARTA_VOLUME_PATH}
done