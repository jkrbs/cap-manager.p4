#!/bin/sh

sudo bash <<EOF
	ip link set enp7s0 up
	ip link set enp8s0 up
	ip link set enp9s0 up
	ip link set enp10s0 up
	ip link set enp11s0 up
	ip link set enp12s0 up

	ip a add 10.0.1.2/24 dev enp7s0
	ip a add 10.0.1.3/24 dev enp8s0

	ip a add 10.0.3.2/24 dev enp9s0
	ip a add 10.0.3.3/24 dev enp10s0

	ip a add 10.0.9.2/24 dev enp11s0
	ip a add 10.0.9.3/24 dev enp12s0

EOF
