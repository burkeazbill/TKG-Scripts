#!/bin/bash
# title       : createClusters.sh
# description : This script will create a specified number of
#               TKG Clusters and SCP the config files to a remote
#               system.
# author      : Burke Azbill
# repo        : https://github.com/burkeazbill/TKG-Scripts
# date        : 2020-10-15
# version     : 1.2
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
# where ## = 01 -> 999 
cluster_name_prefix="tkg-"
# Setup VIP and LB Address array:
# This should be a range of available IPS that are not in a DHCP range
lb_ips=($(echo 172.25.{1..3}.{0..255} | tr ' ' '\012'))
# The above string creates an array that starts at 172.25.1.0
# and iterates through to 172.25.2.255

# lb_address_count : How many addresses should be configured for 
#  the Metal LB Config Map with the default setting of 2,
#  the first cluster will receive .1 for the Cluster VIP and .2 -> .3 for MetalLB config, 
#  the second will receive .4 for the Cluster VIP and .5 -> .6 for the MetalLB config, and so on
lb_address_count=2
#### SCP SETTINGS ####
# Path to private key used to SCP files to desktops:
scp_private_key_path="$HOME/.ssh/id_rsa"

# scp_to_remote : Enable by setting to 1 and disable by setting to 0
scp_to_remote=1
# remote_prefix : Prefix for the remote systems. Suffix will match
#               the suffix of the TKG Cluster (01 -> 99)
remote_prefix="att-cs-l-"
# remote_ssh_username : The name of the user to be used for the scp connection
remote_ssh_username="root"
# remote_folder : The destination folder on the remote system for 
#               the files to be copied to
remote_folder="/etc/skel"

### SSH from Target Desktops to TKG Nodes Settings:
# ssh_pub_key_path : path to alternative SSH public key to be copied
#     to your tkg cluster nodes. Keep this next line commented
#     to use the key that was used at initialization of tkg admin.
#     If you uncomment the next line: fix path to your key AND
#     uncomment the line below for VSPHERE_SSH_AUTHORIZED_KEY
#     The corresponding Private key to the public key specified here
#     Should exist on the target systems. This allows them easy SSH to
#     their assigned TKG Cluster VMs.     
ssh_pub_key_path="$HOME/.ssh/hol-keys/id_rsa.pub"
# K8s version based on Photon image that is uploaded:
k8sversion="v1.17.11+vmware.1"
# Alternate versions for TKG 1.2: v1.18.8-vmware.1, v1.19.1-vmware.2

# TKG CLI OVERRIDES:
# - example usage of overrides:
#   - Change SSH key or use different templates
#   - Change destination Resource Pool or Folder (Could require script changes below)
#     if RP/Folder per cluster is desired
#
#  -- Please note that I have not tested all of the overrides!
# The following Environment variables are set at the time of TKG 
# Admin cluster initialization. If you wish to override, edit and 
# Uncomment as desired:
export VSPHERE_RESOURCE_POOL="/SDDC-Datacenter/host/Cluster-1/Resources/Compute-ResourcePool/tkg/dev"
export VSPHERE_TEMPLATE="/SDDC-Datacenter/vm/Workloads/tkg/photon-3-kube-$k8sversion"
export VSPHERE_FOLDER="/SDDC-Datacenter/vm/Workloads/tkg/dev"
export VSPHERE_SSH_AUTHORIZED_KEY=`cat $ssh_pub_key_path`

# export VSPHERE_DATASTORE="/SDDC-Datacenter/datastore/WorkloadDatastore"
# export VSPHERE_DISK_GIB="40"
# export VSPHERE_MEM_MIB="4096"
# export CLUSTER_CIDR=100.96.0.0/11
# export VSPHERE_NETWORK=vra-attendee-net
# export VSPHERE_DATACENTER="/SDDC-Datacenter"
# export VSPHERE_HAPROXY_TEMPLATE="/SDDC-Datacenter/vm/Workloads/tkg/photon-3-haproxy-v1.2.4+vmware.1"
# export VSPHERE_PASSWORD='put-your-own-vcenter-pw-here'
# export VSPHERE_USERNAME='yourvcenteruser@vsphere.local'
# export VSPHERE_NUM_CPUS="2"
# export VSPHERE_SERVER=place-vcenter-fqdn-here

# Worker Node Overrides:
# VSPHERE_WORKER_DISK_GIB
# VSPHERE_WORKER_MEM_MIB
# VSPHERE_WORKER_NUM_CPUS

# Control Plane Overrides:
# VSPHERE_CONTROL_PLANE_DISK_GIB
# VSPHERE_CONTROL_PLANE_MEM_MIB
# VSPHERE_CONTROL_PLANE_NUM_CPUS 

###### You should not need to modify below this line ######
# hms function source:
# https://www.shellscript.sh/tips/hms/
echo "`date`: Starting the script."
# Define hms() function
hms()
{
  # Convert Seconds to Hours, Minutes, Seconds
  # Optional second argument of "long" makes it display
  # the longer format, otherwise short format.
  local SECONDS H M S MM H_TAG M_TAG S_TAG
  SECONDS=${1:-0}
  let S=${SECONDS}%60
  let MM=${SECONDS}/60 # Total number of minutes
  let M=${MM}%60
  let H=${MM}/60
  
  if [ "$2" == "long" ]; then
    # Display "1 hour, 2 minutes and 3 seconds" format
    # Using the x_TAG variables makes this easier to translate; simply appending
    # "s" to the word is not easy to translate into other languages.
    [ "$H" -eq "1" ] && H_TAG="hour" || H_TAG="hours"
    [ "$M" -eq "1" ] && M_TAG="minute" || M_TAG="minutes"
    [ "$S" -eq "1" ] && S_TAG="second" || S_TAG="seconds"
    [ "$H" -gt "0" ] && printf "%d %s " $H "${H_TAG},"
    [ "$SECONDS" -ge "60" ] && printf "%d %s " $M "${M_TAG} and"
    printf "%d %s\n" $S "${S_TAG}"
  else
    # Display "01h02m03s" format
    [ "$H" -gt "0" ] && printf "%02d%s" $H "h"
    [ "$M" -gt "0" ] && printf "%02d%s" $M "m"
    printf "%02d%s\n" $S "s"
  fi
}

if [ -n "$1" ]; then
  ##### Initialize Timer #####
  start_time=`date +%s`
  ##### Initialize Cleanup Script #####
  cleanup_script="deleteClusters-"$start_time".sh"
  echo \# Cleanup Script > $cleanup_script
  chmod +x $cleanup_script
  ##### Start Address Calculations #####
  let ips_needed=(lb_address_count + 1)
  echo "IPs needed per cluster: "$ips_needed
  total_avail_ips=${#lb_ips[@]}
  echo "Total Available IPs: "$total_avail_ips
  let total_required_ips=( $1 * $ips_needed )
  echo "Total Required IPs: "$total_required_ips
  echo "#############################################"
  # Make sure there are enough IP Addresses available
  # for each Cluster VIP and MetalLB Pool
  if [[ $total_required_ips -gt $total_avail_ips ]]; then
    echo "Insufficient IPs to meet deployment requirements"
    exit
  fi
  (( lb_diff = $lb_address_count - 1 ))
  ##### Begin Main creation loop #####
  for i in $(seq 1 "$1"); do
    c_start=`date +%s`
    cluster_number=`printf %03d $i`
    clustername="$cluster_name_prefix$cluster_number"
    echo $clustername
    # Get Cluster VIP address
    # Define Load Balancer Range:
    (( lb_end = i*$ips_needed ))
    (( cluster_ip = $lb_end - $lb_address_count ))
    (( lb_start = $lb_end - $lb_diff ))
    lb_range="${lb_ips[$lb_start]}-${lb_ips[$lb_end]}"
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
    echo "Running: tkg create cluster $clustername -c 1 -w 2 -p dev"
    echo "kubeconfig and metal-lb yaml will be placed in /etc/skel"
    echo "which means it will be in each user home directory upon first login"
    echo "With LB Range: $lb_range"
    echo "And Cluster VIP: "${lb_ips[$cluster_ip]}
    # The following line updated to control size of nodes and allow for K8s version selection
    tkg create cluster $clustername -c 1 -w 2 -p dev --controlplane-size medium --worker-size medium  --kubernetes-version $k8sversion --vsphere-controlplane-endpoint-ip ${lb_ips[$cluster_ip]}
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
      scp -i $scp_private_key_path -o StrictHostKeyChecking=no ./$clustername.kubeconfig $remote_ssh_username@$remote_system:$remote_folder
      scp -i $scp_private_key_path -o StrictHostKeyChecking=no ./metal-lb-$cluster_number.yaml $remote_ssh_username@$remote_system:$remote_folder
    fi
    c_end=`date +%s`
    let c_elapsed=${c_end}-${c_start}
    echo "===== Cluster Create Time ====="
    cluster_time=`hms $c_elapsed`
    echo "Cluster creation time: ${cluster_time}"
    echo "#############################################"
  done
  end_time=`date +%s`
  let elapsed=${end_time}-${start_time}
  echo "=================== Total Script Run Time ========================="
  total_time=`hms $elapsed long`
  echo "Total script time: ${total_time}"
else
  echo "Usage: createClusters.sh <NumOfClusters>"
  echo "IE: createClusters.sh 5"
fi
