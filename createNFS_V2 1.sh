#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <NFS-Generic-server-FQDN> <NFS-Smarta-server-FQDN> <Generic_volume_path> <Smarta_volume_path> <UID> <GID> [<NFS-version>]"
    exit 1
fi

MOUNT_POINT="/mnt/nfs"
NFS_SERVER_G=$1
NFS_SERVER_S=$2
GENERIC_VOLUME_PATH=${3:-""}
SMARTA_VOLUME_PATH=${4:-""}
SUITE_USER_UID=$5
SUITE_USER_GID=$6
NFS_VERSION=${7:-"4"}
NFS_PARENT="var/vols/itom"

if [ ! -d $MOUNT_POINT/${GENERIC_VOLUME_PATH} ]; then
    mkdir -p $MOUNT_POINT/${GENERIC_VOLUME_PATH}
    #mkdir -p /mnt/nfs/generic
fi

if [ ! -d $MOUNT_POINT/${SMARTA_VOLUME_PATH} ]; then
    mkdir -p $MOUNT_POINT/${SMARTA_VOLUME_PATH}
    #mkdir -p /mnt/nfs/smarta
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

mountNFS_Generic() {
    local VOLUME_FOLDER_NAME=$1
    mount -t nfs -o nfsvers=${NFS_VERSION} ${NFS_SERVER_G}:/${VOLUME_FOLDER_NAME} ${MOUNT_POINT}/${VOLUME_FOLDER_NAME}
    #mount -t nfs -o nfsvers=4 10.246.4.68:/smax-generic-qa /mnt/nfs/smax-generic-qa
    if [ $? -eq 0 ] || [ $? -eq 32 ]; then
        echo "Successfully mount ${VOLUME_FOLDER_NAME}"
        #echo "Successfully mount smax-generic-qa"
        sed -i '$a\'"$NFS_SERVER_G:/${VOLUME_FOLDER_NAME} $MOUNT_POINT/${VOLUME_FOLDER_NAME} nfs nfsvers=${NFS_VERSION} 0 0" /etc/fstab
        #sed -i '$a\'"10.246.4.68:/smax-generic-qa /mnt/nfs/smax-generic-qa nfs nfsvers=4 0 0" /etc/fstab
    else
        echo "Could not mount ${VOLUME_FOLDER_NAME}"
        #echo "Could not mount smax-generic-qa"
        exit 1
    fi
}

# mountNFS_Smarta() {
#     local VOLUME_FOLDER_NAME=$1
#     mount -t nfs -o nfsvers=${NFS_VERSION} ${NFS_SERVER_S}:/${VOLUME_FOLDER_NAME} ${MOUNT_POINT}/${VOLUME_FOLDER_NAME}
#     #mount -t nfs -o nfsvers=4 10.246.4.69:/smax-volume-qa /mnt/nfs/smax-generic-qa
#     if [ $? -eq 0 ] || [ $? -eq 32 ]; then
#         echo "Successfully mount ${VOLUME_FOLDER_NAME}"
#         #echo "Successfully mount smax-volume-qa"
#         sed -i '$a\'"$NFS_SERVER_S:/${VOLUME_FOLDER_NAME} $MOUNT_POINT/${VOLUME_FOLDER_NAME} nfs nfsvers=${NFS_VERSION} 0 0" /etc/fstab
#         #sed -i '$a\'"10.246.4.69:/smax-volume-qa /mnt/nfs/smax-volume-qa nfs nfsvers=4 0 0" /etc/fstab
#     else
#         echo "Could not mount ${VOLUME_FOLDER_NAME}"
#         #echo "Could not mount smax-volume-qa"
#         exit 1
#     fi
# }

#Función que será llamada en un ciclo (Se comentan ejemplos solo uno de cada NFS generic y smarta)
make_volume() {
    local VOLUME=$1
    #local VOLUME=itsma/logging-volume  (Ciclo generic x3)
    #local VOLUME=itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    local VOLUME_FOLDER_NAME=$2
    #local VOLUME_FOLDER_NAME=smax-generic-qa (Ciclo generic x3)
    #local VOLUME_FOLDER_NAME=smax-volume-qa (Ciclo smarta x23)
    pushd $(pwd)
    cd ${MOUNT_POINT}/${VOLUME_FOLDER_NAME}
    #cd /mnt/nfs/smax-generic-qa (Ciclo generic x3)
    #cd /mnt/nfs/smax-volume-qa (Ciclo smarta x23)

    local MOUNTED_PV=${MOUNT_POINT}/${VOLUME_FOLDER_NAME}/${NFS_PARENT}/${VOLUME}
    #local MOUNTED_PV=/mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
    #local MOUNTED_PV=/mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    if [ ! -d ${MOUNTED_PV} ]; then
        mkdir -p ${MOUNTED_PV}
        #mkdir -P /mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
        #mkdir -P /mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    fi
    chown -R ${SUITE_USER_UID}:${SUITE_USER_GID} ${MOUNTED_PV}
    #chown -R 1999:1999 /mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
    #chown -R 1999:1999 /mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    chmod g+w ${MOUNTED_PV}
    #chmod g+w /mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
    #chmod g+w /mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    chmod g+s ${MOUNTED_PV}
    #chmod g+s /mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
    #chmod g+s /mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    chmod u+w ${MOUNTED_PV}
    #chmod u+w /mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
    #chmod u+w /mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    chmod u+s ${MOUNTED_PV}
    #chmod u+s /mnt/nfs/smax-generic-qa/var/vols/itom/itsma/logging-volume (Ciclo generic x3)
    #chmod u+s /mnt/nfs/smax-volume-qa/var/vols/itom/itsma/rabbitmq-infra-rabbitmq-0 (Ciclo smarta x23)
    popd
}

mountNFS_Generic ${GENERIC_VOLUME_PATH}
# mountNFS_Smarta ${SMARTA_VOLUME_PATH}

#ciclos para la función make_volume para generic
for i in "${arr1[@]}"; do
    make_volume ${i} ${GENERIC_VOLUME_PATH}
done

#ciclos para la función make_volume para smarta
# for i in "${arr2[@]}"; do
#     make_volume ${i} ${SMARTA_VOLUME_PATH}
# done

#Ejecución anterior
#sudo ./createNFS.sh <mount_path_ip> <generic_volume_path> <smarta_volume_path> <system_user_id> <system_group_id>

#Ejecución del nuevo script
#sudo ./createNFS_V2.sh <mount_path_Generic_ip> <mount_path_Smarta_ip> <generic_volume_path> <smarta_volume_path> <system_user_id> <system_group_id>
#sudo ./createNFS_V2.sh 10.246.4.68 10.246.4.69 smax-generic-qa smax-volume-qa 1999 1999
