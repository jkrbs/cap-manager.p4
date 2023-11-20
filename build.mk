##
# P4 Cap Manager
#
# @file
# @version 0.1
SDE=$(HOME)/bf-sde-9.13.0/
P4_NAME=cap-manager
P4_PATH=src/tofino/main.p4
P4FLAGS=-Isrc/tofino
PTF_TESTS_DIR=src/tests
PORTINFO=src/tofino/ports.json
include utils/p4.mk
# end
