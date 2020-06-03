#!/bin/bash

set -e -u -o pipefail

if [ ! -d /home/vagrant ]; then
  echo "Do not run this script directly, please see README for install instructions."
  exit 1
fi

HOST_IP="$1"
HOST_HOME="$2"

if [ -d /etc/docker ]; then
  echo "Provisioning is not idempotent, please re-install mobymac if needed."
  exit 1
fi

echo "=== Attaching data volume"
mkfs -t ext4 /dev/sdb
echo "/dev/sdb /var/lib/docker ext4 defaults 0 0" >> /etc/fstab
mkdir /var/lib/docker
mount /var/lib/docker

echo "=== Enable experimental server mode (mostly for 'docker build --squash')"
mkdir /etc/docker
echo '{ "experimental": true }' > /etc/docker/daemon.json

echo "=== Make docker daemon listen on TCP port (instead of socket only)"
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/tcp_listen.conf <<EOD
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2376
EOD

echo "=== Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https curl gnupg-agent nfs-common ntp

echo "=== Installing docker"
curl -fsSL https://download.docker.com/linux/debian/gpg |apt-key add -
echo "deb https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce

echo "=== Setting up NFS mount"
mkdir -p "${HOST_HOME}"
echo "${HOST_IP}:${HOST_HOME} ${HOST_HOME} nfs noacl,async,noatime,actimeo=1 0 0" >> /etc/fstab
mount "${HOST_HOME}"
