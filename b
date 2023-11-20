#!/bin/bash
utils/set_sde.bash ~
if [ -d "$1" ]; then 
	make -f build.mk build
elif [ "$1" == "run" ]; then
	make -f build.mk model &
	make -f build.mk veth_setup
	sudo ip a add 10.0.0.10/32 dev veth250
	sudo ip a add 10.0.0.9/32 dev veth251
	make -f build.mk switchd 
else
	make -f build.mk $1
fi
