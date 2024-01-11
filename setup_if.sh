#!/bin/sh

sudo bash <<EOF
	ip netns add client
	ip netns add service
	ip netns add switch

	ip link add name veth1 type veth peer name veth2
	ip link set dev veth1 mtu 10240 up
	ip link set dev veth2 mtu 10240 up

	ip link add name veth3  type veth peer name veth4
	ip link set dev veth3 mtu 10240 up
	ip link set dev veth4 mtu 10240 up

	ip link add name veth9  type veth peer name veth21
	ip link set dev veth9 mtu 10240 up
	ip link set dev veth21 mtu 10240 up

	ip link add name veth10  type veth peer name veth22
	ip link set dev veth22 mtu 10240 up
	ip link set dev veth10 mtu 10240 up
	
	ip link set dev veth1 netns service
	ip link set dev veth3 netns client
	ip link set dev veth9 netns switch
	ip link set dev veth10 netns switch

	ip link set dev veth2 netns switch
	ip link set dev veth4 netns switch

	ip netns exec service ip a add 10.0.1.2/24 dev veth1
	ip netns exec switch ip a add 10.0.1.1/24 dev veth2

	ip netns exec client ip a add 10.0.3.2/24 dev veth3
	ip netns exec switch ip a add 10.0.3.1/24 dev veth4

	ip netns exec switch ip a add 10.0.9.10/31 dev veth10
	ip netns exec switch ip a add 10.0.9.2/31 dev veth9

	ip netns exec switch ip link set veth2 up
	ip netns exec switch ip link set veth4 up
	ip netns exec switch ip link set veth10 up

	ip netns exec service ip link set veth1 up
	ip netns exec client ip link set veth3 up
	ip netns exec switch ip link set veth9 up

	ip link add name br-ctrlplane type bridge
	ip a add dev br-ctrlplane 10.0.9.3/24
	ip a add dev br-ctrlplane 10.0.9.11/24
	ip link set br-ctrlplane up
	ip link set dev veth21 master br-ctrlplane 
	ip link set dev veth22 master br-ctrlplane
	ip link set dev veth21 up
	ip link set dev veth22 up

	ip netns exec switch ip r add 10.0.9.2/31 dev veth9 via 10.0.9.3
	ip netns exec switch ip r add 10.0.9.10/31 dev veth10 via 10.0.9.11

	# ip neigh add dev veth1 to 10.0.1.1 lladdr d2:92:07:39:f4:99
	# ip neigh add dev veth2 to 10.0.1.2 lladdr 1a:50:7b:d7:05:e0
	
	# ip neigh add dev veth3 to 10.0.3.1 lladdr 4e:3c:ba:0d:f8:00
	# ip neigh add dev veth4 to 10.0.3.2 lladdr 2a:fe:e6:c6:39:ca

	# ip neigh add dev veth10 to 10.0.9.2 lladdr 72:fe:7a:19:b0:e9
	# ip neigh add dev veth9 to 10.0.9.1 lladdr e6:e1:8d:3d:2c:9b

	ip netns exec switch ip l set lo up
	ip netns exec switch ip a add dev lo 127.0.0.1/8
	ip netns exec client ip l set lo up
	ip netns exec client ip a add dev lo 127.0.0.1/8
	ip netns exec service ip l set lo up
	ip netns exec service ip a add dev lo 127.0.0.1/8

	ip netns exec service ip r add 10.0.0.0/16 via 10.0.1.1
	ip netns exec client ip r add 10.0.0.0/16 via 10.0.3.1
EOF
