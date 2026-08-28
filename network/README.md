# ha-shim: let the PC reach its own Home Assistant VM

The HA VM (`homeassistant`, libvirt) uses a macvtap interface on enp6s0. macvtap guests are
reachable from the LAN but NOT from the host itself (no host<->macvtap hairpin). Fix: a macvlan
sibling interface on the host, plus a /32 host route to HA via it.

Restore:  sudo cp ha-shim.nmconnection /etc/NetworkManager/system-connections/ && sudo chmod 600 /etc/NetworkManager/system-connections/ha-shim.nmconnection && sudo nmcli con reload && sudo nmcli con up ha-shim
Remove:   sudo nmcli con delete ha-shim
Test:     curl -s -o /dev/null -w '%{http_code}\n' http://192.168.0.128:8123/   # 200

The shim gets its own DHCP lease (its own MAC), never-default, so all other traffic still uses enp6s0.
Added 2026-08-27.
Also: append network/hosts.append to /etc/hosts (mDNS for the HA VM does not work through the shim).
