# The Hardware and OS for RPi Cluster

We use 3 RaspberryPi 4 to build the cluster.

## Hardware

We use 3 RaspberryPi 4 (4GB RAM) with 3 PoE Hat mounted to a stacking stand.
![RPi Cluster](https://user-images.githubusercontent.com/944672/81684895-acc6d980-9457-11ea-9973-099d5d08f38c.jpeg)

## OS Flashing

We use [balenaEtcher](https://www.balena.io/etcher/) to flash the OS onto SD card. Since [RaspberryPi OS-64 bit](https://www.raspberrypi.org/forums/viewtopic.php?f=117&t=275370) is not in mature state yet, thus we chose [Ubuntu 20.04 LTS](https://ubuntu.com/download/raspberry-pi) instead.

## Initial config

After flashing the OS into SD Card, following initial config are applied.

- Set unique hostname for every RPi.

```bash
sudo hostnamectl set-hostname <HOSTNAME>
```

- Apply Docker related config by appending following text into `/boot/firmware/cmdline.txt`.

```
cgroup_enable=memory cgroup_memory=1
```

- Adjust the fan temp control by adding following text into `/boot/firmware/usecfg.txt`.

```
dtparam=poe_fan_temp0=65000,poe_fan_temp0_hyst=5000
dtparam=poe_fan_temp1=77000,poe_fan_temp1_hyst=2000
```

- Add NFS support

```bash
sudo apt update && sudo apt -y install nfs-common
```
