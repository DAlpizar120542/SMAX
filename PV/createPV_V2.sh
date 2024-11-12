#!/bin/bash
# Copyright 2017 - 2024 Open Text.

# The only warranties for products and services of Open Text and its affiliates and licensors ("Open Text")
# are as may be set forth in the express warranty statements accompanying such products and services.
# Nothing herein should be construed as constituting an additional warranty. Open Text shall not be liable
# for technical or editorial errors or omissions contained herein. The information contained herein is subject
# to change without notice.

# Except as specifically indicated otherwise, this document contains confidential information and a valid
# license is required for possession, use or copying. If this work is provided to the U.S. Government,
# consistent with FAR 12.211 and 12.212, Commercial Computer Software, Computer Software
# Documentation, and Technical Data for Commercial Items are licensed to the U.S. Government under
# vendor's standard commercial license.

usage() {
  echo "Usage: $0  [-n|--namespace <namespace>] [-s|--nfs-server <nfs-server>] [-p|--nfs-root-path <nfs-root-path>] [-f|--file <file>]"
  echo "       -n|--namespace                     Name space."
  echo "       -s|--nfs-server                    The FQDN/IP of the NFS server/NFS server Generic. Required only for on-promise,openshift,AWS,GCP platform."
  echo "       -sm|--nfs-server-smarta            The FQDN/IP of the NFS server Smarta. Required only for on-promise,openshift,AWS,GCP platform."
  echo "       -p|--nfs-root-path                 The generic path on the NFS server."
  echo "       -sp|--nfs-root-path-for-smarta     The smarta path on the NFS server. Only different with generic path in netapp storage. If not provide, will use the same value as --nfs-root-path."
  echo "       -f|--file                          The PV yaml file."
  echo "       -u|--uid                           Required for Suite user UiD. Required only for AzureFile."
  echo "       -g|--gid                           Suite user GiD.Required only for AzureFile."
  echo "       -a|--azureFile                     Required for azureFile"
  echo "       -size|--size                       Size of the Suite. eg small/medium/large"
  echo "       -h|--help                          Show help."
  echo -e "
Examples:
1)   For on-promise: $0  -n itsma -s test.example.net -p /var/vols/itom/itsma --size small
2)   For Azure Netapp: $0  -n itsma -s 10.2.3.4 -p /generic/var/vols/itom/itsma  -sp /smarta/var/vols/itom/itsma  --size small
2.1)   For Azure Netapp: $0  -n itsma -s 10.2.3.4 -sm 10.2.3.5 -p /generic/var/vols/itom/itsma  -sp /smarta/var/vols/itom/itsma  --size small
3)   For Azure File: $0  -n itsma  -p generic/var/vols/itom/itsma  -u 10000 -g 10000 -a --size small"
#./createPV_V2.sh -n itsma -s 10.246.4.68 -sm 10.246.4.69 -p /smax-generic-qa/var/vols/itom/itsma -sp /smax-volume-qa/var/vols/itom/itsma --size small
  exit 1
}

function createPV() {
  if [ -z "$NFS_Server_smarta" ]; then
    NFS_Server_smarta=$NFS_Server
  fi
  if echo "$NFS_Server" | grep -q "efs"; then
    platform="efs";
  fi
  jq -c '.pv[]' storageConfig.json | while IFS= read -r element; do
    if [ "$platform" == "azureFile" ]; then
      create=$(echo $element | jq .platform.azureFile -r)
      if [ "$create" == "false" ]; then
        continue
      fi
    fi
    pvName=$(echo $element | jq .name -r)
    pvAccessMode=$(echo $element | jq .accessModes -r)
    storageClassName=$(echo $element | jq .storageClassName -r)
    pvSize=$(echo $element | jq .storage.${size} -r)
    pathKeyName=$(echo $element | jq .pathKeyName -r)
    nfsPath=${!pathKeyName}
    echo "################# Start to create PV ${pvName} ########################"
     if [ "$platform" == "azureFile" ]; then
      storageConfig=$(
        cat <<EOL
  csi:
    driver: file.csi.azure.com
    volumeHandle: ${nfsPath}/${pvName}
    readOnly: false
    volumeAttributes:
      secretName: azure-secret
      secretNamespace: ${NAMESPACE}
      shareName: ${nfsPath}/${pvName}
  
  mountOptions:
    - dir_mode=0775
    - uid=${UiD}
    - gid=${GiD}
    - mfsymlinks
    - nobrl
EOL
      )
    elif [ "$platform" == "efs" ]; then
      storageConfig=$(
        cat <<EOL
  mountOptions:
    - noresvport
  csi:
    driver: efs.csi.aws.com
    volumeHandle: $(echo $NFS_Server | awk -F'.' '{print $1}'):${nfsPath}/${pvName}
EOL
      )
    else
        if [[ ${pvName} == "logging-volume" ]] || [[ ${pvName} == "config-volume" ]] || [[ ${pvName} == "data-volume" ]]; then
            echo "###Generic###"
            storageConfig=$(
            cat <<EOL
            nfs:
            path: ${nfsPath}/${pvName}
            server: ${NFS_Server}
EOL
    )
        else
	   echo "###Smarta###"
           storageConfig=$(
           cat <<EOL
           nfs:
           path: ${nfsPath}/${pvName}
           server: ${NFS_Server_smarta}
EOL
    )
          fi
    fi
    template=$(
      cat <<EOL
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${NAMESPACE}-${pvName}
spec:
  accessModes:
    - ${pvAccessMode}
  capacity:
    storage: ${pvSize}
${storageConfig}
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${storageClassName}
  claimRef:
    name: ${pvName}
    namespace: ${NAMESPACE}
  volumeMode: Filesystem
EOL
    )
    printf "%s\n" "$template" |kubectl create -f -
    #printf "%s\n" "$template"
    echo "Success created PV ${pvName}"

  done
}

while [[ ! -z $1 ]]; do
  case "$1" in
  -n | --namespace)
    case "$2" in
    -*)
      echo "-n|--namespace parameter requires a value. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-n|--namespace parameter requires a value. "
        exit 1
      fi
      NAMESPACE=$2
      shift 2
      ;;
    esac
    ;;
  -s | --nfs-server)
    case "$2" in
    -*)
      echo "-s|--nfs-server-generic parameter requires a value. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-s|--nfs-server-generic parameter requires a value. "
        exit 1
      fi
      NFS_Server=$2
      shift 2
      ;;
    esac
    ;;
  -sm | --nfs-server-smarta)
    case "$2" in
    -*)
      echo "-s|--nfs-server-smarta parameter requires a value. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-s|--nfs-server-smarta parameter requires a value. "
        exit 1
      fi
      NFS_Server_smarta=$2
      shift 2
      ;;
    esac
    ;;
  -p | --nfs-root-path)
    case "$2" in
    -*)
      echo "-p|--nfs-root-path parameter requires a value. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-p|--nfs-root-path parameter requires a value. "
        exit 1
      fi
      NFS_Root_Path=$2
      shift 2
      ;;
    esac
    ;;
  -sp | --nfs-root-path-for-smarta)
    case "$2" in
    -*)
      echo "-sp|--nfs-root-path-for-smarta parameter requires a value. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-sp|--nfs-root-path-for-smarta parameter requires a value. "
        exit 1
      fi
      NFS_Root_Path_For_SmartA=$2
      shift 2
      ;;
    esac
    ;;
  -u | --uid)
    case "$2" in
    -*)
      echo "-u|--uid. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-u|--uid parameter requires a value. "
        exit 1
      fi
      UiD=$2
      shift 2
      ;;
    esac
    ;;
  -g | --gid)
    case "$2" in
    -*)
      echo "-g|--gid. "
      exit 1
      ;;
    *)
      if [[ -z $2 ]]; then
        echo "-g|--gid parameter requires a value. "
        exit 1
      fi
      GiD=$2
      shift 2
      ;;
    esac
    ;;
  -size | --size)
      case "$2" in
      -*)
        echo "-size|--size. "
        exit 1
        ;;
      *)
        if [[ -z $2 ]]; then
          echo "-size|--size. parameter requires a value. "
          exit 1
        fi
        size=$2
        shift 2
        ;;
      esac
      ;;
  -a | --azureFile)
    case "$2" in
    -*)
      azureFile=true
      platform=azureFile
      shift 1
      ;;
    *)
      if [[ ! -z $2 ]]; then
        echo "-a|--azure paramter do not requires a value."
        exit 1
      fi
      azureFile=true
      platform=azureFile
      shift 1
      ;;
    esac
    ;;

  * | -* | -h | --help | /? | help) usage ;;
  esac
done
if [ -z "$NAMESPACE" ]; then
  echo "Abort installation because the '--namespace' is missing."
  exit 1
fi

if [ -z "$NFS_Root_Path" ]; then
  echo "Abort installation because the '--nfs-root-path' is missing."
  exit 1
fi

if [ -z "$NFS_Root_Path_For_SmartA" ]; then
  NFS_Root_Path_For_SmartA=$NFS_Root_Path
fi

createPV
