#!/bin/bash

sudo bash <<EOF
	ip a add 10.0.1.2/24 dev enp216s0f1
	ip a add 10.0.2.2/24 dev enp216s0f0
	ip link set enp216s0f1 up
	ip link set enp216s0f0 up
EOF
