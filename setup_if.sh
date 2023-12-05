#!/bin/sh

sudo bash <<EOF
	ip link add name veth1  type veth peer name veth2
	ip link set dev veth1 mtu 10240 up
	ip link set dev veth2 mtu 10240 up

	ip link add name veth3  type veth peer name veth4
	ip link set dev veth3 mtu 10240 up
	ip link set dev veth4 mtu 10240 up

	ip link add name veth9  type veth peer name veth10
	ip link set dev veth9 mtu 10240 up
	ip link set dev veth10 mtu 10240 up

	ip a add 10.0.0.1/24 dev veth1
	ip a add 10.0.0.3/24 dev veth3
	ip a add 10.0.0.9/24 dev veth9

	arp -s 10.0.0.3 -i veth1  d2:92:07:39:f4:99
	arp -s 10.0.0.1 -i veth3 4e:3c:ba:0d:f8:00 
	arp -s 10.0.0.9 -i veth9 e6:e1:8d:3d:2c:9b
EOF
