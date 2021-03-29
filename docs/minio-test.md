# Minio server for testing

This document describes how to setup a Minio cluster (consits of 2 Minio servers and a load-balancer) for testing purpose.

## Preparation

Before start, we need to do some preparations in order to setup the cluster. The following actions needs to be taken on all the nodes.

### Hardware and OS

We use 2 Rapsberry Pi(s) with [Raspberry Pi OS](https://www.raspberrypi.org/software/) (64bit) pre-installed. Raspberry Pi OS is a Debian-like operating system with full Linux kernel and Libc.

### DNS resolution config

In order to let minio server run as a distributed cluster, we need to add some configurations in the /etc/hosts file in order to let 2 servers recognize each other. Put following lines into /etc/hosts.

```text
# Assume:
# 192.168.11.19 is the IP of 1st Minio server
# 192.168.11.20 is the IP of 2nd Minio server.
192.168.11.19  minio-1
192.168.11.20  minio-2

127.0.0.1 localhost
```

### Create directories to simulate hard drives used by Minio

Distributed Minio requires many hard drives for High-Availability purpose and the number of hard drives must be divisible by 4. In reality, we need to mount the 4 different hard drives to the 4 created folders.

```bash
# Create 4 folders to simulate 4 disks
sudo mkdir -p /data1 /data2 /data3 /data4
```

## Deployment

When the hardware and OS are ready. We are about to install the Minio server and related software onto the servers. The following actions needs to be taken on all the nodes.

### Install Minio server

We download the latest Minio deb binary followed [Minio Download](https://min.io/download#/linux) and choose the proper package (Linux/ARM64 for RPi 4).

```bash
wget https://dl.min.io/server/minio/release/linux-arm64/minio_20210326000041.0.0_arm64.deb
sudo dpkg -i minio_20210326000041.0.0_arm64.deb
```

### Prepare systemd service and configuration file

In order to let Minio run as a service, we prepare a systemd service descriptor file **/lib/systemd/system/minio.service** looks like below:

```text
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local

User=root
Group=root

EnvironmentFile=-/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

# Let systemd restart this service always
# Restart=always

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536

# Specifies the maximum number of threads this process can create
TasksMax=infinity

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

# Built for ${project.name}-${project.version} (${project.name})
```

Meanwhile, create a file named **/etc/default/minio** with following content **N.B.** Remember to change the MINIO_USERNAME and MINIO_ADMIN_PASSWORD to secret values. Remember, the values must be identical for all the Minio server on various nodes.

```text
# Remote volumes to be used for MinIO server.
MINIO_VOLUMES=http://minio-{1...2}:9000/data{1...4}

# Root user for the server.
MINIO_ROOT_USER=<MINIO_ADMIN_USERNAME>
# Root secret for the server.
MINIO_ROOT_PASSWORD=<MINIO_ADMIN_PASSWORD>
```

### Start Minio server on both nodes

Now we can launch Minio server on both nodes. Run following commands to start Minio server.

```bash
sudo systemctl enable minio
sudo systemctl start minio
```

## Load-balancing

In order to create a single endpoint of the Minio cluster. We create a loadbalancer (NGINX) to perform the task.

### Install Nginx

Install Nginx is quite simple on Debian based system. We can use any machine (or Raspberry Pi) with Debian-like system installed acting as the Load-Balancer and install Nginx.

```bash
sudo apt-get update
sudo apt-get install nginx -y
```

### Configure Nginx for Minio Loadbalancing

Create one file named **/etc/nginx/sites-available/minio** with following content (Here we assume 192.168.11.19 and 192.168.11.20 are the IP addresses of 2 Minio servers, change them if it doesn't match the reality).

```text
 upstream minio {
    server 192.168.11.19:9000;
    server 192.168.11.20:9000;
}
# proxy_cache_path /minio/cache levels=1:2 keys_zone=my_cache:10m max_size=10g inactive=60m
                 use_temp_path=off;

server {
    listen 80;
    # To allow special characters in headers
    ignore_invalid_headers off;
    # Allow any size file to be uploaded.
    # Set to a value such as 1000m; to restrict file size to a specific value
    client_max_body_size 0;
    # To disable buffering
    proxy_buffering off;

    location / {
        proxy_pass http://minio;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;

        proxy_connect_timeout 300;
        # Default is HTTP/1, keepalive is only enabled in HTTP/1.1
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;
    }
}
```

Create a softlink in Nginx configuration and reload Nginx service.

```bash
cd /etc/nginx/sites-enabled
rm default
sudo ln -s ../sites-available/minio

sudo systemctl restart nginx
```

## Validate

Now you should be ready for upload/download files with the Minio cluster. We can use Minio Client (mc) to validate this.

### Install mc binary

We shall install mc via binary following [Minio Client Installation](https://min.io/download#/linux).

### Connect to server

After downloading Minio Client, we can use it to connect to the server(s) and playing with it. Remember to change **LOAD_BALANCER_IP**, **MINIO_ADMIN_USERNAME** and **MINIO_ADMIN_PASSWORD** to correct value.

```bash
mc alias set minio http://<LOAD_BALANCER_IP> <MINIO_ADMIN_USERNAME> <MINIO_ADMIN_PASSWORD>
```

### Check the server and create the bucket

```bash
mc admin info minio

# Example output:
# $  mc admin info minio
# ●  minio-1:9000
#    Uptime: 4 hours
#    Version: 2021-03-26T00:00:41Z
#    Network: 2/2 OK
#    Drives: 4/4 OK
#
# ●  minio-2:9000
#    Uptime: 4 hours
#    Version: 2021-03-26T00:00:41Z
#    Network: 2/2 OK
#    Drives: 4/4 OK
#
# 107 MiB Used, 2 Buckets, 5 Objects
# 8 drives online, 0 drives offline
```

### Test creating bucket, upload/download files

We can do more test via creating bucket

```bash
mc mb <BUCKET_NAME>

# Example
# $  mc mb minio/testbucket
# Bucket created successfully `minio/testbucket`.
```

And upload a local file

```bash
mc cp /path/to/local/file minio/testbucket

# Example
# mc cp Downloads/FMS_Manual.pdf minio/testbucket
# Downloads/FMS_Manual.pdf:    3.36 MiB / 3.36 MiB  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  1.59 MiB/s 2s
```

Of course create a download link for downloading the file

```bash
mc share download --expire=<EXPIRING_PERIOD> <PATH/TO/FILE>

# Example
# mc share download --expire=10m minio/testbucket/FMS_Manual.pdf
# URL: http://192.168.11.10/testbucket/FMS_Manual.pdf
# Expire: 10 minutes 0 seconds
# Share: http://192.168.11.10/testbucket/FMS_Manual.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin%2F20210329%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20210329T170339Z&X-Amz-Expires=600&X-Amz-SignedHeaders=host&X-Amz-Signature=e392431852d239f196edda0107e83d20ba6bec81d029a7644d552d2a033997bd

curl <SHARE_LINK> --output /path/to/local/file

# Example:
# url https://192.168.11.10/testbucket/FMS_Manual.pdf\?X-Amz-Algorithm\=AWS4-HMAC-SHA256\&X-Amz-Credential\=minioadmin%2F20210329%2Fus-east-1%2Fs3%2Faws4_request\&X-Amz-Date\=20210329T170339Z\&X-Amz-Expires\=600\&X-Amz-SignedHeaders\=host\&X-Amz-Signature\=e392431852d239f196edda0107e83d20ba6bec81d029a7644d552d2a033997bd --output FMS_Manual.pdf
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 3440k  100 3440k    0     0   828k      0  0:00:04  0:00:04 --:--:--  829k
```
