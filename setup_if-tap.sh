#!/bin/sh

sudo bash <<EOF

	ip tuntap add mode tap tapctrlplanesw  # 
	ip tuntap add mode tap tapctrlplanecpu # 
	
	
	address e6:e1:8d:3d:2c:9b mtu 10240 up
	 address 72:fe:7a:19:b0:e9 mtu 10240 up
	ip a add 10.0.9.1/24 dev tapctrlplanesw
	ip a add 10.0.9.2/24 dev tapctrlplanecpu

	ip link add name veth1  type veth peer name veth2
	ip link set dev veth1 mtu 10240 up
	ip link set dev veth2 mtu 10240 up

	ip link add name veth3  type veth peer name veth4
	ip link set dev veth3 mtu 10240 up
	ip link set dev veth4 mtu 10240 up

	ip a add 10.0.1.2/24 dev veth1
	ip a add 10.0.3.2/24 dev veth3

	ip a add 10.0.1.1/24 dev veth2
	ip a add 10.0.3.1/24 dev veth4

	ip r add 10.0.0.0/8 dev veth3 via 10.0.3.1 metric 300
	ip r add 10.0.0.0/8 dev veth1 via 10.0.1.1 metric 100

	ip neigh add dev veth1 to 10.0.1.1 lladdr d2:92:07:39:f4:99
	ip neigh add dev veth2 to 10.0.1.2 lladdr 1a:50:7b:d7:05:e0
	ip neigh add dev veth3 to 10.0.3.1 lladdr 4e:3c:ba:0d:f8:00
	ip neigh add dev veth4 to 10.0.3.2 lladdr 2a:fe:e6:c6:39:ca

EOF
