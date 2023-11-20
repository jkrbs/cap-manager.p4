#!/bin/sh

sudo bash <<EOF
	ip link del veth1
	ip link del veth3
EOF
