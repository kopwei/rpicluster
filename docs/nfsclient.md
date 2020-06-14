# NFS Client Storage Solution

This document is about how to deploy the NFS-Client storage class on the RPi cluster in order to allocate persistent volumes on the NFS server.

## NFS provisioner

I have an Synology diskstation home with NFS server enabled. In order to get pvc support on K3s cluster, i use following command to deploy the NFS client provisioner.

```bash
helm -n nfs-provisioner install diskstation \
  stable/nfs-client-provisioner \
  --set nfs.server=<DISKSTATION_IP> \
  --set nfs.path=<NFS_MOUNTING_PATH> \
  --set image.repository=kopkop/nfs-client-provisioner-arm64
```

N.B. Remember to install **NFS client** on every worker node first if it is not pre-installed.

```bash
sudo apt update && sudo apt -y install nfs-common
```
