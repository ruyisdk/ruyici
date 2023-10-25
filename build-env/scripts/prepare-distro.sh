#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive
# HTTPS needs ca-certificates to work
sed -i 's@http://archive\.ubuntu\.com/@http://mirrors.huaweicloud.com/@g' /etc/apt/sources.list

apt-get update
apt-get upgrade -qqy
apt-get install -y build-essential ca-certificates git wget
