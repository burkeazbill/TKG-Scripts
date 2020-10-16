# TKG-Scripts

## Overview

The scripts contained in this repository have been written to address needs that I (or my team) have needed around Tanzu Kubernetes Grid (TKG).

## createClusters

As an enablement team, the VMware Cloud Services [Livefire](https://www.livefire.solutions) team needs to be able to deploy TKG Clusters to VMware Cloud on AWS quickly and consistently for up to 25 attendees. On special occasions such as Empower, we may need in excess of 100 clusters available. As of the 1.2 release of Tanzu Kubernetes Grid, this script has been updated to support 3 digit cluster name extensions and matching desktops.

Our attendees will each be given a Linux Ubuntu based Horizon Desktop with some name, for example: ATT-CS-L-001. At the time of TKG Cluster creation, the kubeconfig for the cluster number matching the attendee desktop number should be copied to the desktop via SCP. Additionally, a small range of IP addresses should be populated in a Kubernetes config map yaml file and placed on the attendee desktop as well for use in one of the labs.

![Horizon-TKG-Diagram](assets/Horizon-TKG-Diagram.png)

The first script in this repository: [createClusters.sh](https://github.com/burkeazbill/TKG-Scripts/blob/master/createClusters.sh) addresses the above need.

I've tried to make the script as reusable as possible.

### Prerequisites

- **tkg** binary should already be installed
- tkg management cluster should already be initialized
- **~/.tkg** should be present on system to run this script - with valid _config.yaml_
- DHCP Range of addresses capable of supporting the maximum number of Controller Nodes and Worker Nodes you would need to deploy
- Static IP range of addresses (Defined in the **lb_ips** variable in the top section, line 26, of the createClusters.sh script)
 ```lb_ips=($(echo 172.25.{1..3}.{0..255} | tr ' ' '\012'))```
 to be used for:
  - the Controller Node VIP (1 per cluster)
  - the MetalLB ConfigMap IP range 
- Configure number of MetalLB LoadBalancer IP Addresses (Suggest minimum of 1 per cluster, set **lb_address_count** in top section, line 34, of the createClusters.sh script)
 ```lb_address_count=2```

**Usage:**

```bash
# ./createClusters.sh ## ( ## should be a number from 1-999)
# For example:
createClusters.sh 25
```

**NOTE:** _The script will auto-detect and exit, with error message, if the required number of static IPs (for Cluster VIPs and MetalLB Ranges) exceeds the number of available IP addresses that get defined in the **lb_ips** line of the script._

Without modification, the above command should result in:

- 25 single master/2 worker clusters named: tkg-001 - tkg-025

![tkg-clusters-in-vmc-on-aws](/assets/tkg-clusters-in-vmc-on-aws.png)

- Kubeconfig merged into Local ~/.kube/config for each cluster

![tkg-kubeconfig-merged](/assets/tkg-kubeconfig-merged.png)

- 25 metal-lb-###.yaml files containing configuration for a range of 2 ip addresses from your defined Static IP range
- 25 tkg-###.kubeconfig files (one for each cluster created)
- 25 IPs from your defined Static IP range allocated to each cluster VIP for API Load Balancing
- The .yaml and .kubeconfig files copied to corresponding remote system with suffix ### - matching the cluster number
- A cleanup script that:
  - Deletes each tkg cluster
  - Deletes the .kubeconfig and .yaml
  - Removes the Cluster, Context, and User from the local .kube/config file (these were merged into the local config as the credentials were exported during the script in early versions of TKG. Keeping this just in case you have gone ahead and merged the config yourself)

```shell
# Cleanup Script
tkg delete cluster tkg-001 -y
kubectl config unset clusters.tkg-001
kubectl config unset contexts.tkg-001-admin@tkg-001
kubectl config unset users.tkg-001-admin
rm tkg-001.kubeconfig
rm metal-lb-001.yaml
tkg delete cluster tkg-002 -y
kubectl config unset clusters.tkg-002
kubectl config unset contexts.tkg-002-admin@tkg-002
kubectl config unset users.tkg-002-admin
rm metal-lb-002.yaml
rm tkg-002.kubeconfig
```

## ToDo

- Update screenshots to reflect updated 3 digit suffix ###
- Update script to have # of Controllers as config setting
- Update script to have # of Workers as config setting

## Accessing App running on multiple K8s Clusters behind Traefik

Content coming soon, but here's a tease screenshot:

![tkg-kubeconfig-merged](/assets/traefik-to-multiple-k8s.png)
