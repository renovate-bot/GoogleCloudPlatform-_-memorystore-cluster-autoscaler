#!/bin/bash
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu

# Increase limits
cat << EOF > /etc/security/limits.d/test-vm-limits.conf
root soft nofile 1048576
root hard nofile 1048576
* soft nofile 1048576
* hard nofile 1048576
EOF

# Write instructional banner
cat << 'EOF' > /etc/motd

    __  ___                                     __                     ______          __  __                    __
   /  |/  /__  ____ ___  ____  _______  _______/ /_____  ________     /_  __/__  _____/ /_/ /_  ___  ____  _____/ /_
  / /|_/ / _ \/ __ `__ \/ __ \/ ___/ / / / ___/ __/ __ \/ ___/ _ \     / / / _ \/ ___/ __/ __ \/ _ \/ __ \/ ___/ __ \
 / /  / /  __/ / / / / / /_/ / /  / /_/ (__  ) /_/ /_/ / /  /  __/    / / /  __(__  ) /_/ /_/ /  __/ / / / /__/ / / /
/_/  /_/\___/_/ /_/ /_/\____/_/   \__, /____/\__/\____/_/   \___/    /_/  \___/____/\__/_.___/\___/_/ /_/\___/_/ /_/
                                 /____/

  Generate CPU load:                                $ memorystore-cpu-load
  Bulk-write to increase memory utilisation (1GB):  $ memorystore-write-1gb
  Bulk-write to increase memory utilisation (10GB): $ memorystore-write-10gb
  Flush all keys:                                   $ memorystore-flush-all
  Connect to the cluster in interactive mode:       $ redis-cli -c -h cluster.memorystore.private

  Functions are defined in /etc/profile.d/memorystore-functions.sh.

  Note that the underlying utilities may take a few minutes to become available on first boot.

EOF

# Install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y
apt-get install redis-tools build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev git libssl-dev htop -y

# Install utility for load generation
export reddissim_version='v0.1.7'
export golang_version='1.21.4'
cd /root
git clone https://github.com/maguec/RedisSim.git && cd RedisSim
git checkout ${reddissim_version}
wget https://go.dev/dl/go${golang_version}.linux-amd64.tar.gz
tar -C /usr/local -xzf go${golang_version}.linux-amd64.tar.gz
export HOME=/root
export GOPATH=${HOME}/go
export GOMODCACHE=${GOPATH}/pkg/mod
export PATH=$PATH:/usr/local/go/bin
make
mv RedisSim /usr/local/bin/RedisSim

# Define commands and make available
memorystore_cpu_load_cmd="RedisSim cpukill --clients 100 --size 1000 --loop-forever --server cluster.memorystore.private --cluster"
memorystore_write_1gb_cmd="RedisSim stringfill --prefix \$(date +'%s') --clients 100 --size 1000 --string-count 1000000 --server cluster.memorystore.private --cluster"
memorystore_write_10gb_cmd="RedisSim stringfill --prefix \$(date +'%s') --clients 100 --size 1000 --string-count 10000000 --server cluster.memorystore.private --cluster"
memorystore_flush_all_cmd="redis-cli --cluster call --cluster-only-masters cluster.memorystore.private:6379 FLUSHALL"

cat << EOF > /etc/profile.d/memorystore-functions.sh
function memorystore-cpu-load () {
  ${memorystore_cpu_load_cmd}
}
function memorystore-write-10gb () {
  ${memorystore_write_10gb_cmd}
}
function memorystore-write-1gb () {
  ${memorystore_write_1gb_cmd}
}
function memorystore-flush-all () {
  ${memorystore_flush_all_cmd}
}
export -f memorystore-cpu-load
export -f memorystore-write-10gb
export -f memorystore-write-1gb
export -f memorystore-flush-all
EOF
