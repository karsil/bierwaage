#!/bin/bash
# 1. Format the volume if it's new
echo "Starting setup.sh"

echo "Waiting for /dev/sdb to be attached..."
for i in {1..30}; do
    if [ -b /dev/sdb ]; then
        echo "/dev/sdb found!"
        break
    fi
    echo "Device not found yet, retrying in 1s..."
    sleep 1
done

if [ ! -b /dev/sdb ]; then
    echo "Error: /dev/sdb never appeared. Exiting."
    exit 1
fi

# 3. Format only if it doesn't have a filesystem yet (prevents data loss on reboot)
if ! blkid /dev/sdb; then
    mkfs.ext4 /dev/sdb
fi

mkdir -p /mnt/docker_data
mount /dev/sdb /mnt/docker_data

# 2. Install Docker
apt-get update
apt-get install -y docker.io docker-compose

# 3. Symlink Docker to the persistent volume (optional)
# This ensures all images/containers live on the persistent disk
# systemctl stop docker
# mv /var/lib/docker /mnt/docker_data/
# ln -s /mnt/docker_data/docker /var/lib/docker
# systemctl start docker

# 4. Deploy your app
cd /home/ubuntu
git clone https://github.com/karsil/bierwaage.git
cd bierwaage

# Use the persistent volume for the DuckDB data directory
mkdir -p /mnt/docker_data/data
ln -s /mnt/docker_data/data data

# Write .env so docker-compose picks up DB_PATH (injected by Terraform templatefile)
echo 'DB_PATH=${DB_PATH}' > .env

docker-compose up -d
