# Introduction

Currently this script has only been tested on Debian 12, and it is recommended to install it on a freshly installed, clean Debian 12 system. 

Perhaps I will add more systems support in the future.

# Usage

## Install

```
./wireguard_deploy.sh install
```

## Add user

```
./wireguard_deploy.sh authorize client2 "10.200.200.2"
```

This will generate a file named wg0.conf in the directory /etc/wireguard/client/client2/wg0.conf, and assign the client a static IP address of 10.200.200.2. Note that the IP address must be in the same subnet as the option_server_subnet_ip defined in the script.

## Remove user

```
./openvpn_deploy.sh revoke client1
```

This will remove the authorization of the client1 user, and client1 can not connect to the vpn server anymore. Maybe you should restart wg-quick@wg0.service to make the change take effect.

## Uninstall

```
./openvpn_deploy.sh uninstall
```

This will remove all the configuration files in /etc/wireguard/*, and delete firewall rules.

## Help

```
./openvpn_deploy.sh help
```

Display a short help message.
