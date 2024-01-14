## Generic Tofino P4 Project Makefile Shortcuts

# Must have P4_NAME and P4_PATH
ifndef P4_NAME
$(error P4_NAME is not set)
endif
ifndef P4_PATH
$(error P4_PATH is not set)
else
override P4_PATH := $(realpath $(P4_PATH))
endif


# Test dir is generally ptf-tests
PTF_TESTS_DIR?=ptf-tests

# Basic test params
ifdef TOFINO2
ARCH_TEST_PARAM = 'tofino2'
else
ARCH_TEST_PARAM = 'tofino'
endif
ifdef HW_TARGET
TARGET_TEST_PARAM = 'hw'
else
TARGET_TEST_PARAM = 'asic-model'
endif
ifndef SWITCH_IP
SWITCH_IP = localhost
endif
ifdef PORTINFO
PORT_INFO_PAR = -f $(PORTINFO)
else
PORT_INFO_PAR = ""
endif
TEST_PARAMS_INT = p4_name='$(P4_NAME)';arch=$(ARCH_TEST_PARAM);target=${TARGET_TEST_PARAM}

# Test params can be given from outside
ifdef TEST_PARAMS
TEST_PARAMS_INT := $(addsuffix ;$(TEST_PARAMS) , $(TEST_PARAMS_INT))
endif

# Add prefix for tests
TEST_PARAMS_INT := $(addsuffix "$(TEST_PARAMS_INT)",--test-params=)

# Build parameters
ifdef TOFINO2
ADDITIONAL_CMAKE_ARGUMENTS = '-DTOFINO2=ON'
else
ADDITIONAL_CMAKE_ARGUMENTS = ''
endif
ifdef P4FLAGS
	override P4FLAGS += --verbose 3 -v -g -Xp4c='--set-max-power 50'
else
	P4FLAGS = --verbose 3 -v -g -Xp4c='--set-max-power 50'
endif
ADDITIONAL_CMAKE_ARGUMENTS := $(addsuffix "$(ADDITIONAL_CMAKE_ARGUMENTS)",-DP4FLAGS="${P4FLAGS}")
# Build directory is generally in the same directory.
ifndef BUILD_DIR
BUILD_DIR = ./build 
endif

# We create a run dir to get all logs into it.
.PHONY: veth_setup veth_teardown build model switchd bfshell \
	bfrt_setup_i bfrt_setup clean clean_logs clean_build vis tests tests_list test
# Build the P4
build:
	echo "Bulding ${P4_NAME} from ${P4_PATH} at ${BUILD_DIR} with ${ADDITIONAL_CMAKE_ARGUMENTS}"
	rm -rf ${BUILD_DIR}; mkdir -p ${BUILD_DIR};
	cd ${BUILD_DIR}
	cmake ${SDE}/p4studio/ -DCMAKE_INSTALL_PREFIX=${SDE_INSTALL} -DCMAKE_MODULE_PATH=${SDE}/cmake -DP4_NAME=${P4_NAME} -DP4_PATH=${P4_PATH} -DP4_LANG=${P4_LANG} ${ADDITIONAL_CMAKE_ARGUMENTS}
	make ${P4_NAME}
	make install
	echo "SUCCESS!"


# Veth setup and teardown must be done at the start
veth_setup:
	sudo ${SDE_INSTALL}/bin/veth_setup.sh
veth_teardown:
	sudo ${SDE_INSTALL}/bin/veth_teardown.sh

P4_LANG ?= p4-16

# Run the P4
model:
	${SDE}/run_tofino_model.sh -p ${P4_NAME} $(PORT_INFO_PAR)
model-quiet:
	${SDE}/run_tofino_model.sh -q -p ${P4_NAME} $(PORT_INFO_PAR)

switchd:
	${SDE}/run_switchd.sh -p ${P4_NAME}

# Run independent bfshell
bfshell:
	${SDE}/run_bfshell.sh

# Visualization
vis:
	${SDE_INSTALL}/bin/p4i -w build/${P4_NAME}/tofino

# Run setup
bfrt_setup:
	${SDE}/run_bfshell.sh -b bfrt_python/setup.py
bfrt_setup_i:
	${SDE}/run_bfshell.sh -b bfrt_python/setup.py -i

# Run PTF test
tests:
	env PKTPY=false PYTHONPATH=pkt:${PYTHONPATH} ${SDE}/run_p4_tests.sh --no-veth --ip $(SWITCH_IP) $(PORT_INFO_PAR) -p ${P4_NAME} -t ${PTF_TESTS_DIR} ${TEST_PARAMS_INT}
tests_list:
	env PKTPY=false PYTHONPATH=pkt:${PYTHONPATH} ${SDE}/run_p4_tests.sh --no-veth --ip $(SWITCH_IP) $(PORT_INFO_PAR) -p ${P4_NAME} -t ${PTF_TESTS_DIR} -- --list
test:
	env PKTPY=false PYTHONPATH=pkt:${PYTHONPATH} ${SDE}/run_p4_tests.sh --no-veth --ip $(SWITCH_IP) $(PORT_INFO_PAR) -p ${P4_NAME} -t ${PTF_TESTS_DIR} -s ${TEST} ${TEST_PARAMS_INT}


# TODO: Run regression

# Cleanup
clean:
	sudo rm -rf bf_drivers.log* *.pcap ptf.log ptf.pcap model*.log pcap_output zlog* dummy.tofino
clean_build:
	sudo rm -rf build
