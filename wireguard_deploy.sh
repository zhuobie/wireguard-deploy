#!/bin/bash
set -euo pipefail

command=""
sub_command=""
sub_sub_command=""

if [ $# -eq 0 ]; then
    command="help"
fi

if [ $# -eq 1 ]; then
    command=$1
fi

if [ $# -eq 2 ]; then
    command=$1
    sub_command=$2
fi

if [ $# -eq 3 ]; then
    command=$1
    sub_command=$2
    sub_sub_command=$3
fi

if [ $# -gt 3 ]; then
    echo "Too many arguments"
    exit 1
fi

#### Modify these parameters as needed. ####
option_server_connect_ip="192.168.52.146" 
option_server_vpn_port="18135" 
option_server_subnet_ip="10.200.200.1/24"
#### Modify these parameters as needed. ####

server_ip=$(echo "$option_server_subnet_ip" | cut -d '/' -f1)
cidr=$(echo "$option_server_subnet_ip" | cut -d '/' -f2)

help() {
    echo "Usage: $0 [OPTION]"
    echo "  uninstall                        Uninstall VPN server, and delete all configs."
    echo "  install                          Install VPN Server."
    echo "  authorize client1 <ip addr>      Add client authorization."
    echo "  revoke client1                   Revoke client authorization." 
    echo "  help                             Show this help message"
}

install_ufw() {
    if command -v ufw >/dev/null 2>&1; then
        ufw disable
        ufw allow $option_server_vpn_port/udp
        ufw reload
    fi
}

uninstall_ufw() {
    if command -v ufw >/dev/null 2>&1; then
        ufw disable
        ufw delete allow $option_server_vpn_port/udp
        ufw reload
    fi
}

uninstall() {
    if [[ -f "/etc/wireguard/wg0.conf" ]]; then
        wg-quick down wg0
    fi
    systemctl disable wg-quick@wg0.service
    systemctl stop wg-quick@wg0.service
    rm -rf /etc/wireguard/*
    uninstall_ufw
}

client_authorize() {
    client_name=$1
    client_ip=$2
    mkdir -p /etc/wireguard/client/$client_name
    wg genkey | tee /etc/wireguard/client/$client_name/privatekey | wg pubkey > /etc/wireguard/client/$client_name/publickey
    wg set wg0 peer $(cat /etc/wireguard/client/$client_name/publickey) allowed-ips $client_ip/32

    echo "
# $client_name
[Peer]
PublicKey = $(cat /etc/wireguard/client/$client_name/publickey)
AllowedIPs = $client_ip/32" >> /etc/wireguard/wg0.conf

    echo "[Interface]
PrivateKey = $(cat /etc/wireguard/client/$client_name/privatekey)
Address = $client_ip/$cidr
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/server/publickey)
AllowedIPs = $client_ip/$cidr
Endpoint = $option_server_connect_ip:$option_server_vpn_port
PersistentKeepalive = 25" > /etc/wireguard/client/$client_name/wg0.conf
}

client_revoke() {
    client_name=$1
    wg set wg0 peer $(cat /etc/wireguard/client/$client_name/publickey) remove
    line_number=$(grep -n "^\#\s$client_name" /etc/wireguard/wg0.conf | cut -d: -f1)
    sed -i "$((line_number-1)),$((line_number+3))d" /etc/wireguard/wg0.conf
    rm -rf /etc/wireguard/client/${client_name}
}

install_server() {
    apt install -y wireguard
    mkdir -p /var/log/wireguard
    mkdir -p /etc/wireguard/server
    mkdir -p /etc/wireguard/client
    wg genkey | tee /etc/wireguard/server/privatekey | wg pubkey > /etc/wireguard/server/publickey
    echo "[Interface]
Address = $server_ip/$cidr
ListenPort = $option_server_vpn_port
PrivateKey = $(cat /etc/wireguard/server/privatekey)
SaveConfig = true" > /etc/wireguard/wg0.conf
    systemctl restart wg-quick@wg0
    systemctl enable wg-quick@wg0
    install_ufw
}

if [[ "$command" == "help" ]]; then
    help
    exit 0
fi

if [[ "$command" == "install" ]]; then
    install_server
    exit 0
fi

if [[ "$command" == "uninstall" ]]; then
    uninstall
    exit 0
fi

if [[ "$command" == "authorize" ]]; then
    client_authorize "$sub_command" "$sub_sub_command"
fi

if [[ "$command" == "revoke" ]]; then
    client_revoke "$sub_command"
fi

# Examples
## ./wireguard_deploy.sh help
## ./wireguard_deploy.sh uninstall
## ./wireguard_deploy.sh install
## ./wireguard_deploy.sh authorize client1
## ./wireguard_deploy.sh authorize client1 auto
## ./wireguard_deploy.sh authorize client2 "192.168.90.2"
## ./wireguard_deploy.sh revoke client1
