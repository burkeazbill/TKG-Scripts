# TKG-Scripts

## Overview

The scripts contained in this repository have been written to address needs that I (or my team) have needed around the Tanzu Kubernetes Grid (TKG).

## createClusters.sh

As an enablement team, the VMware Cloud Services [Livefire](https://www.livefire.solutions) team needs to be able to deploy TKG Clusters to VMware Cloud on AWS quickly and consistently for up to 25 attendees.

Our attendees will each be given a Linux Ubuntu based Horizon Desktop with some name, for example: ATT-CS-L-01. At the time of TKG Cluster creation, the kubeconfig for the cluster number matching the attendee desktop number should be copied to the desktop via SCP. Additionally, a small range of IP addresses should be populated in a Kubernetes config map yaml file and placed on the attendee desktop as well for use in one of the labs.

![Horizon-TKG-Diagram](assets/Horizon-TKG-Diagram.png)

The first script in this repository: createClusters.sh addresses the above need.

I've tried to make the script as reusable as possible.

### Prerequisites

- tkg binary should already be installed
- tkg admin cluster should already be initialized
- ~/.tkg should be present on system to run this script - with valid _config.yaml_

**Usage:**

```bash
# ./createClusters.sh ## ( ## should be a number from 1-99)
# For example:
createCluster.sh 25
```

Without modification, the above command should result in:

- 25 single master/5 worker clusters named: tkg-01 - tkg-25

![tkg-clusters](/assets/tkg-clusters.png)

![tkg-clusters-in-vmc-on-aws](/assets/tkg-clusters-in-vmc-on-aws.png)

- Kubeconfig merged into Local ~/.kube/config for each cluster

![tkg-kubeconfig-merged](/assets/tkg-kubeconfig-merged.png)

- 25 metal-lb-##.yaml files containing configuration for a range of 4 ip addresses
- 25 tkg-##.kubeconfig files (one for each cluster created)
- The .yaml and .kubeconfig files copied to corresponding remote system with suffix ## - matching the cluster number
- A cleanup script that:
  - Deletes each tkg cluster
  - Deletes the .kubeconfig and .yaml
  - Removes the Cluster, Context, and User from the local .kube/config file (these were merged into the local config as the credentials were exported during the script)

```bash
# Cleanup Script
tkg delete cluster tkg-01 -y
kubectl config unset clusters.tkg-01
kubectl config unset contexts.tkg-01-admin@tkg-01
kubectl config unset users.tkg-01-admin
rm tkg-01.kubeconfig
rm metal-lb-01.yaml
tkg delete cluster tkg-02 -y
kubectl config unset clusters.tkg-02
kubectl config unset contexts.tkg-02-admin@tkg-02
kubectl config unset users.tkg-02-admin
rm metal-lb-02.yaml
rm tkg-02.kubeconfig
```

## My next challenge

I've seen plenty of blog posts and info on how to get Traefik to route to Docker containers on the same Docker host, and how to route to things within a Kubernetes cluster that Traefik is installed inside of ... however, I have been unable to figure out the best approach to the following:

![tkg-kubeconfig-merged](/assets/traefik-to-multiple-k8s.png)

In this scenario, we have a training environment that has up to 25 Kubernetes clusters deployed (1 cluster per attendee). These all get deployed via Tanzu Kubernetes Grid (TKG), which results in admin kubeconfigs also being generated. This is all done with the script here in my repo. What I would like to also do is route *.k8s.example.com (port 80 only!) to internal clusters that match the host portion of the requested FQDN to their cluster name on nodeport 32000.

For example, if a user opens their browser to http:/cluster-03.k8s.example.com, I want Traefik to route that request to the Kubernetes masters in cluster-03.internal.lab and send the traffic to the nodeport the attendees will configure as part of their exercises. This would allow each user to view their running service from outside our lab environment.

Does anyone here have any experience with this type of configuration? I don't want any changes to the infra as shown in the diagram as its purpose is to provide some hands-on with VMware's TKG created clusters.

Thanks!
