##
# P4 Cap Manager
#
# @file
# @version 0.1
P4_NAME=cap-manager
P4_PATH=src/tofino/main.p4
P4FLAGS=-I $(realpath ./src/tofino)

include utils/p4.make
# end
