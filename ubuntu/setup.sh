#!/bin/bash
set -euo pipefail

if (( $# > 1 )); then echo 'Usage: setup.sh [docker-user]' >&2; exit 2; fi
docker_user=${1:-}
if [[ -n "$docker_user" ]]; then
  id -- "$docker_user" >/dev/null
fi

arch=$(dpkg --print-architecture)
case "$arch" in amd64|arm64) ;; *) echo "Unsupported Node.js architecture: $arch" >&2; exit 1 ;; esac
. /etc/os-release
keydir=$(mktemp -d)
trap 'rm -rf -- "$keydir"' EXIT
sudo apt-get update --error-on=any
sudo apt-get install -y ca-certificates curl gnupg make python3 build-essential libpng-dev pkg-config nasm
sudo install -m 0755 -d /etc/apt/keyrings /usr/share/keyrings

# Use the same source and keyring paths as the NodeSource installer.
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o "$keydir/nodesource.asc"
fingerprints=$(gpg --batch --with-colons --show-keys "$keydir/nodesource.asc" |
  awk -F: '$1 == "pub" { primary = 1 } primary && $1 == "fpr" { print $10; primary = 0 }')
if [[ "$fingerprints" != '6F71F525282841EEDAF851B42F59B5F99B1BE0B4' ]]; then
  echo 'Unexpected NodeSource signing key. Verify the upstream key before proceeding.' >&2
  exit 1
fi
gpg --batch --dearmor --output "$keydir/nodesource.gpg" "$keydir/nodesource.asc"
sudo install -m 0644 "$keydir/nodesource.gpg" /usr/share/keyrings/nodesource.gpg
sudo tee /etc/apt/sources.list.d/nodesource.sources >/dev/null <<SOURCES
Types: deb
URIs: https://deb.nodesource.com/node_24.x
Suites: nodistro
Components: main
Architectures: $arch
Signed-By: /usr/share/keyrings/nodesource.gpg
SOURCES

curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$keydir/docker.asc"
sudo install -m 0644 "$keydir/docker.asc" /etc/apt/keyrings/docker.asc
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" |
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update --error-on=any
sudo apt-get install -y 'nodejs=24.*' docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [[ -n "$docker_user" ]]; then
  sudo usermod -aG docker -- "$docker_user"
  echo "Log out and back in as $docker_user to use Docker."
fi
