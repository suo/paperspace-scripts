#!/bin/bash
set -euxo pipefail

my_ip=$(hostname -I | tr -d ' ')
sccache_dir="$HOME/sccache-dist"
if [[ -e "$sccache_dir" ]]; then
	rm -rf "$sccache_dir"
fi
mkdir "$sccache_dir"
cd "$sccache_dir"

# Install sccache-dist dependencies
sudo apt-get update
sudo apt-get install bubblewrap

# Download sccache-dist release
wget "https://github.com/mozilla/sccache/releases/download/v0.3.0/sccache-dist-v0.3.0-x86_64-unknown-linux-musl.tar.gz"
tar -xvf "sccache-dist-v0.3.0-x86_64-unknown-linux-musl.tar.gz" "sccache-dist-v0.3.0-x86_64-unknown-linux-musl/sccache-dist" --strip-components=1
rm "sccache-dist-v0.3.0-x86_64-unknown-linux-musl.tar.gz"
chmod +x sccache-dist

# Set up the build server configuration
cat << EOF > server.conf
# This is where client toolchains will be stored.
cache_dir = "/tmp/toolchains"
# The maximum size of the toolchain cache, in bytes.
# If unspecified the default is 10GB.
# toolchain_cache_size = 10737418240
# A public IP address and port that clients will use to connect to this builder.
public_addr = "${my_ip}:10501"
# The URL used to connect to the scheduler (should use https, given an ideal
# setup of a HTTPS server in front of the scheduler)
scheduler_url = "http://10.225.63.3:10600"

[builder]
type = "overlay"
# The directory under which a sandboxed filesystem will be created for builds.
build_dir = "/tmp/build"
# The path to the bubblewrap version 0.3.0+ bwrap binary.
bwrap_path = "/usr/bin/bwrap"

[scheduler_auth]
# type = "jwt_token"
# This will be generated by the generate-jwt-hs256-server-token command or
# provided by an administrator of the sccache cluster.
# token = "my server's token"
type = "DANGEROUSLY_INSECURE"
EOF

# Set the systemd service that will run the server
cat << EOF > sccache-server.service
[Unit]
Description=sccache-dist server
Wants=network-online.target
After=network-online.target

[Service]
ExecStart="$sccache_dir"/sccache-dist server --config "$sccache_dir"/server.conf

[Install]
WantedBy=multi-user.target
EOF
sudo mv sccache-server.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl start sccache-server
sudo systemctl status sccache-server.service
sudo systemctl enable sccache-server # This enables the service on boot
