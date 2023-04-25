#!/bin/bash
# Deploy shadowsocks-rust server on Debian and Ubuntu
# updated: 2023-04
# https://xinlake.dev


# check root
if [[ $EUID -ne 0 ]]; then
    echo "This script only supports running as root"
    exit 0
fi

# get system info
sysId=$(lsb_release --short --id | tr "[:upper:]" "[:lower:]")
sysArch=$(arch)
sysBits=$(getconf LONG_BIT)

if [[ $sysId != "debian" && $sysId != "ubuntu" ]]; then
    echo "This script only supports Debian and Ubuntu systems"
    exit 0
fi

ssPackageUrl="https://github.com/xinlake/privch-server/raw/main/.lfs/ss.rust-v1.15.3"
case $sysArch in
    "i686")
        ssPackageUrl="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v1.15.3/shadowsocks-v1.15.3.i686-unknown-linux-musl.tar.xz"
        ;;
    "x86_64")
        ssPackageUrl="${ssPackageUrl}-linux-gnu-x64.tar.xz"
        ;;
    ""|*)
        echo "This script only supports x86 and x86-64 machines"
        exit 0
        ;;
esac

# upgrade packages, install packages
apt update
apt install -y tar wget ufw

# install shadowsocks-rust
ssHome=/usr/local/xinlake-shadowsocks-rust
mkdir -m 0755 -p $ssHome

if [[ ! -f "$ssHome/ssserver" ]]; then
    echo "Download shadowsocks-rust ..."
    wget --quiet --output-document $ssHome/shadowsocks-rust.tar.xz $ssPackageUrl

    tar -xf $ssHome/shadowsocks-rust.tar.xz --directory $ssHome
    rm $ssHome/shadowsocks-rust.tar.xz
fi

# create script
cat > $ssHome/ss-rust.sh << EOF
#!/bin/bash

funcStart() {
    ssPortList=( 7039 7040 )

    # setup firewall, enable ssh and shadowsocks port
    ufw allow 22/tcp
    for ufwPort in \${ssPortList[@]}; do
        ufw allow \$ufwPort/tcp
        ufw allow \$ufwPort/udp
    done
    ufw --force enable

    # start shadowsocks server
    for ssPort in \${ssPortList[@]}; do
        $ssHome/ssserver --server-addr "[::]:\$ssPort" --encrypt-method "aes-256-gcm" --password "hello-ss" -U &
    done
}

funcStop() {
    pkill --full "ssserver"
}

case \$1 in
    "start")
        funcStart
        ;;
    "stop")
        funcStop
        ;;
    "restart")
        funcStop
        funcStart
        ;;
    ""|*)
        echo "Invalid arguments"
        echo
        ;;
esac
EOF

# create service
cat > /etc/systemd/system/ss-rust.service << EOF
[Unit]
Description=SS-Rust
After=network.target

[Service]
Type=forking
ExecStart=$ssHome/ss-rust.sh start
ExecStop=$ssHome/ss-rust.sh stop
ExecRestart=$ssHome/ss-rust.sh restart 

[Install]
WantedBy=multi-user.target
EOF

# enable and start service
chmod +x $ssHome/ss-rust.sh
systemctl enable ss-rust.service
systemctl start ss-rust.service

# done
echo "Shadowsocks server ready"