# oui-app-wireless-repeater

Wireless Repeater app for OUI (OpenWrt UI)

Features:
- List wireless devices (radios)
- Scan nearby Wi-Fi via iwinfo
- Configure STA interface bound to `repeater` network (DHCP)
- Reload wireless and network, and show connection status

Backend RPC: `files/rpc/wireless-repeater.lua`
Frontend: `htdoc/index.vue`
