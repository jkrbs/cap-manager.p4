#!/bin/sh

sudo bash <<EOF
	ip netns del switch
	ip netns del client
	ip netns del service
	ip netns del control-plane
EOF
