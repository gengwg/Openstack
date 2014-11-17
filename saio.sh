#!/bin/env bash
# 
# Install Swift on one server (Swift All In One - SAIO).
# Currently only working on Ubuntu.
# Centos on work.
#
# Usage:
#       ./saio.sh (as root user)
#
# Author: Weigang Geng <gengwg [at] gmail.com>
# 
#
# 

### Set your OpenStack source to Grizzly
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/grizzly main" > /etc/apt/sources.list.d/grizzly.list

# You need to get the key
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 5EDB1B62EC4926EA

apt-get update

### Install necessary packages

apt-get install -y curl gcc memcached rsync sqlite3 xfsprogs git-core python-setuptools

apt-get install -y python-coverage python-dev python-nose python-simplejson python-xattr python-eventlet python-greenlet python-pastedeploy python-netifaces python-pip python-dnspython python-mock python-memcache python-webob

# Install swift packages
apt-get install -y swift swift-account swift-container swift-object swift-proxy

### Set up the storage
# Set up a single partition (enter n, p - select defaults, then w)
echo "Now setting up a single partition. Enter 'n', select all defaults, then w)"
fdisk /dev/sdb

# Format partition
mkfs.xfs -i size=1024 /dev/sdb1

# Add to /etc/fstab
echo "/dev/sdb1 /mnt/sdb1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab

# Make and mount /mnt/sdb1
mkdir /mnt/sdb1
mount /mnt/sdb1

# Make, own and mount sub- and other directories
mkdir -p /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4 /srv /etc/swift/object-server /etc/swift/container-server /etc/swift/account-server /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift
chown swift: /mnt/sdb1/*
chown -R swift: /etc/swift /srv/[1-4]/ /var/run/swift
ln -s /mnt/sdb1/1 /srv/1
ln -s /mnt/sdb1/2 /srv/2
ln -s /mnt/sdb1/3 /srv/3
ln -s /mnt/sdb1/4 /srv/4

#Add the following lines to /etc/rc.local
cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown swift: /var/cache/swift*
mkdir -p /var/run/swift
chown swift: /var/run/swift

exit 0

EOF



### Set up rsync and memcached

# Create /etc/rsyncd.conf with the following contents:
cat > /etc/rsyncd.conf <<EOF
uid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 127.0.0.1

[account6012]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account6022]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account6032]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account6042]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock

[container6011]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container6021]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container6031]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container6041]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock

[object6010]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock

[object6020]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object6030]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object6040]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock

EOF

# Edit the following line in /etc/default/rsync:
sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync

# Restart rsync
service rsync restart
# Restart memcached
service memcached restart


### Create configuration files
# Add the following line to /etc/swift/container-server.conf
cat >> /etc/swift/container-server.conf <<EOF

[container-sync]
EOF

# Create proxy server config file /etc/swift/proxy-server.conf

cat > /etc/swift/proxy-server.conf <<EOF
[DEFAULT]
bind_port = 8080
user = swift
log_facility = LOG_LOCAL1
eventlet_debug = true

[pipeline:main]
pipeline = healthcheck cache tempauth proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache

[filter:proxy-logging]
use = egg:swift#proxy_logging

EOF

# Create the main swift config file

cat > /etc/swift/swift.conf << EOF
[swift-hash]
# random unique strings that can never change (DO NOT LOSE)
swift_hash_path_prefix = myprefix
swift_hash_path_suffix = mysuffix
EOF

# Create the four account server config files
# /etc/swift/account-server/1.conf
cat > /etc/swift/account-server/1.conf << EOF
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6012
user = swift
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cat > /etc/swift/account-server/2.conf << EOF
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6022
user = swift
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cat > /etc/swift/account-server/3.conf << EOF
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6032
user = swift
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF


cat > /etc/swift/account-server/4.conf << EOF
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6042
user = swift
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

# Create the four container server config files
cat > /etc/swift/container-server/1.conf << EOF
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6011
user = swift
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat > /etc/swift/container-server/2.conf << EOF
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6021
user = swift
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat > /etc/swift/container-server/3.conf << EOF
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6031
user = swift
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server
[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat > /etc/swift/container-server/4.conf << EOF
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6041
user = swift
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF


# Create the four object server config files
cat > /etc/swift/object-server/1.conf << EOF
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6010
user = swift
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true
[pipeline:main]
pipeline = recon object-server
[app:object-server]
use = egg:swift#object
[filter:recon]
use = egg:swift#recon
[object-replicator]
vm_test_mode = yes
[object-updater]
[object-auditor]
EOF

cat > /etc/swift/object-server/2.conf << EOF
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6020
user = swift
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true
[pipeline:main]
pipeline = recon object-server
[app:object-server]
use = egg:swift#object
[filter:recon]
use = egg:swift#recon
[object-replicator]
vm_test_mode = yes
[object-updater]
[object-auditor]
EOF

cat > /etc/swift/object-server/3.conf << EOF
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6030
user = swift
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true
[pipeline:main]
pipeline = recon object-server
[app:object-server]
use = egg:swift#object
[filter:recon]
use = egg:swift#recon
[object-replicator]
vm_test_mode = yes
[object-updater]
[object-auditor]
EOF

cat > /etc/swift/object-server/4.conf << EOF
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6040
user = swift
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true
[pipeline:main]
pipeline = recon object-server
[app:object-server]
use = egg:swift#object
[filter:recon]
use = egg:swift#recon
[object-replicator]
vm_test_mode = yes
[object-updater]
[object-auditor]
EOF

### Setup the ring - run all of these commands in the /etc/swift directory
cd /etc/swift

# Create the rings
swift-ring-builder object.builder create 18 3 1
swift-ring-builder container.builder create 18 3 1
swift-ring-builder account.builder create 18 3 1

# Add devices to the object ring
swift-ring-builder object.builder add z1-127.0.0.1:6010/sdb1 1
swift-ring-builder object.builder add z2-127.0.0.1:6020/sdb2 1
swift-ring-builder object.builder add z3-127.0.0.1:6030/sdb3 1
swift-ring-builder object.builder add z4-127.0.0.1:6040/sdb4 1
# Rebalance the object ring
swift-ring-builder object.builder rebalance

# Add devices to the container ring
swift-ring-builder container.builder add z1-127.0.0.1:6011/sdb1 1
swift-ring-builder container.builder add z2-127.0.0.1:6021/sdb2 1
swift-ring-builder container.builder add z3-127.0.0.1:6031/sdb3 1
swift-ring-builder container.builder add z4-127.0.0.1:6041/sdb4 1
# Rebalance the container ring
swift-ring-builder container.builder rebalance

# Add devices to the account ring
swift-ring-builder account.builder add z1-127.0.0.1:6012/sdb1 1
swift-ring-builder account.builder add z2-127.0.0.1:6022/sdb2 1
swift-ring-builder account.builder add z3-127.0.0.1:6032/sdb3 1
swift-ring-builder account.builder add z4-127.0.0.1:6042/sdb4 1
# Rebalance the account ring
swift-ring-builder account.builder rebalance

### Start running Swift!!
# Put the tempauth credentials in swift-creds
cat > swift-creds <<EOF
export ST_AUTH=http://localhost:8080/auth/v1.0
export ST_USER=test:tester
export ST_KEY=testing
EOF
# Source the tempauth credentials
. swift-creds
# Restart all Swift services
swift-init all restart

cd -
