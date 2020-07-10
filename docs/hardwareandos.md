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

- Adjust the fan temp control by creating a file with name `/etc/udev/rules.d/50-rpi-fan.rules` and following content.

```
SUBSYSTEM=="thermal"
KERNEL=="thermal_zone0"

# If the temp hits 81C, highest RPM
ATTR{trip_point_0_temp}="82000"
ATTR{trip_point_0_hyst}="3000"
#
# If the temp hits 80C, higher RPM
ATTR{trip_point_1_temp}="81000"
ATTR{trip_point_1_hyst}="2000"
#
# If the temp hits 70C, higher RPM
ATTR{trip_point_2_temp}="71000"
ATTR{trip_point_2_hyst}="3000"
#
# If the temp hits 60C, turn on the fan
ATTR{trip_point_3_temp}="61000"
ATTR{trip_point_3_hyst}="5000"
#
# Fan is off otherwise
```

- Add NFS support

```bash
sudo apt update && sudo apt -y install nfs-common
```
