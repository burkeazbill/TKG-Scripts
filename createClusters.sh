#!/bin/bash
# title       : createClusters.sh
# description : This script will create a specified number of
#               TKG Clusters and SCP the config files to a remote
#               system.
# author      : Burke Azbill
# repo        : https://github.com/burkeazbill/TKG-Scripts
# date        : 2020-05-11
# version     : 1.0    
# usage       : createClusters.sh <clusterCount>
# notes       :
# This script has been written from the start to copy config
# files (kubeconfig and metalLB configMap) to a remote desktop
# via ssh using key based authentication. This assumes the 
# system running the script has a private ssh key that has been
# imported into the remote system's authorized_keys. SCP may be
# Disabled by setting scp_to_remote to 0
#

################ Set Variables #############################
# cluster_name_prefix : the suffix will be in the form of ##
# where ## = 01 -> 99 
cluster_name_prefix="tkg-"
# tkg_subnet : the network on which the Metal LB Load Balancer 
#               range should be created. The last octet will be 
#               filled dynamically
tkg_subnet="172.24.6"
# lb_address_count : How many addresses should be configured for 
#               the Metal LB Config Map with the default setting 
#               of 4, the first cluster will receive .1 -> .4, 
#               second will receive .5 -> .8 and so on
lb_address_count=4
#### SCP SETTINGS ####
# scp_to_remote : Enable by setting to 1 and disable by setting to 0
scp_to_remote=1
# remote_prefix : Prefix for the remote systems. Suffix will match
#               the suffix of the TKG Cluster (01 -> 99)
remote_prefix="att-cs-l-"
# remote_ssh_username : The name of the user to be used for the scp connection
remote_ssh_username="vmware"
# remote_folder : The destination folder on the remote system for 
#               the files to be copied to
remote_folder="/home/$remote_ssh_username"
# ssh_pub_key_path : path to alternative SSH public key to be copied
#               to your tkg cluster nodes. Keep this next line commented
#               to use the key that was used at initialization of tkg admin.
#               If you uncomment the next line: fix path to your key AND
#               uncomment the line below for VSPHERE_SSH_AUTHORIZED_KEY
# ssh_pub_key_path="/home/vmware/tkg-cluster.pub"
# TKG OVERRIDES:
# - example usage of overrides:
#   - Change SSH key or use different templates
#   - Change destination Resource Pool or Folder (Could require script changes below)
#     if RP/Folder per cluster is desired
#
#  -- Please note that I have not tested all of the overrides!
# The following Environment variables are set at the time of TKG 
# Admin cluster initialization. If you wish to override, edit and 
# Uncomment as desired:
# VSPHERE_RESOURCE_POOL=/SDDC-Datacenter/host/Cluster-1/Resources/Compute-ResourcePool/tkg
# VSPHERE_TEMPLATE=/SDDC-Datacenter/vm/Workloads/tkg/photon-3-kube-v1.17.3+vmware.2
# VSPHERE_SSH_AUTHORIZED_KEY=`cat $ssh_pub_key_path`
# VSPHERE_DATASTORE=/SDDC-Datacenter/datastore/WorkloadDatastore
# VSPHERE_DISK_GIB="40"
# VSPHERE_MEM_MIB="4096"
# CLUSTER_CIDR=100.96.0.0/11
# VSPHERE_NETWORK=vra-attendee-net
# VSPHERE_DATACENTER=/SDDC-Datacenter
# VSPHERE_HAPROXY_TEMPLATE=/SDDC-Datacenter/vm/Workloads/tkg/capv-haproxy-v0.6.3
# VSPHERE_PASSWORD='put-your-own-vcenter-pw-here'
# VSPHERE_USERNAME='yourvcenteruser@vsphere.local'
# VSPHERE_FOLDER=/SDDC-Datacenter/vm/Workloads/tkg
# VSPHERE_NUM_CPUS="2"
# VSPHERE_SERVER=place-vcenter-fqdn-here

###### You should not need to modify below this line ######
(( lb_diff = lb_address_count -1 ))
# Define function to convert time:
secs_to_human() {
    if [[ -z ${1} || ${1} -lt 60 ]] ;then
        min=0 ; secs="${1}"
    else
        time_mins=$(echo "scale=2; ${1}/60" | bc)
        min=$(echo ${time_mins} | cut -d'.' -f1)
        secs="0.$(echo ${time_mins} | cut -d'.' -f2)"
        secs=$(echo ${secs}*60|bc|awk '{print int($1+0.5)}')
    fi
    echo "Time Elapsed : ${min} minutes and ${secs} seconds."
}
# Initialize Timer:
start_time="$(date -u +%s)"
# Initialize Cleanup Script
cleanup_script="deleteClusters-"$start_time".sh"
echo \# Cleanup Script > $cleanup_script

if [ -n "$1" ]; then
  for i in $(seq 1 "$1"); do
    c_start="$(date -u +%s)"
    if [ "$i" -lt 10 ]; then
      cluster_number="0$i"
    else
      cluster_number="$i"
    fi
    clustername="$cluster_name_prefix$cluster_number"
    # Define Load Balancer Range:
    (( lb_end = i*lb_address_count ))
    (( lb_start = lb_end - lb_diff ))
    lb_range="$tkg_subnet.$lb_start-$tkg_subnet.$lb_end"
    # Now generate the MetalLB for Layer 2 as per: https://metallb.universe.tf/configuration/
cat  <<EOF > metal-lb-$cluster_number.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $lb_range
EOF
    ################################################
    echo "Running: tkg create cluster $clustername -c 1 -w 5 -p prod"
    echo "With LB Range: $lb_range"
    tkg create cluster $clustername -c 1 -w 5 -p prod
    echo tkg delete cluster $clustername -y >> $cleanup_script
    echo kubectl config unset clusters.$clustername >> $cleanup_script
    echo kubectl config unset contexts.$clustername-admin@$clustername >> $cleanup_script
    echo kubectl config unset users.$clustername-admin >> $cleanup_script
    echo rm $clustername.kubeconfig >> $cleanup_script
    echo rm metal-lb-$cluster_number.yaml >> $cleanup_script
    # Output kubeconfig files for attendees
    tkg get credentials $clustername --export-file $clustername.kubeconfig
    if [ "$scp_to_remote" == "1" ]; then
      remote_system=$remote_prefix$cluster_number
      # Now SCP the config file to the attendee desktop:
      echo Copying /$clustername.kubeconfig to $remote_system
      echo Copying /metal-lb-$cluster_number.yaml to $remote_system
      scp -o StrictHostKeyChecking=no ./$clustername.kubeconfig $remote_ssh_username@$remote_system:$remote_folder
      scp -o StrictHostKeyChecking=no ./metal-lb-$cluster_number.yaml $remote_ssh_username@$remote_system:$remote_folder
    fi
    c_end="$(date -u +%s)"
    c_elapsed="$(($end_time-$start_time))"
    secs_to_human $c_elapsed
  done
else
  echo "Usage: createClusters.sh <NumOfClusters>"
  echo "IE: createClusters.sh 5"
fi
end_time="$(date -u +%s)"
elapsed="$(($end_time-$start_time))"
echo "============================================"
secs_to_human $elapsed
