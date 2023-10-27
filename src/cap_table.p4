#include "packet_types.p4"

control cap_ingress(inout headers hdr) {
    action invalidate() {

    }

    action delegate() {

    }


    // Cap exists and is valid
    action capAllow_forward() {

    }

    // Cap is invalid. Notify request issuer about dropping the packets
    action drop_and_notify() {

    }

    action drop() {
        mark_to_drop();
    }

    table cap_table {
        key = {
            hdr.fractos.cap_id + hdr.ipv4.srcAddr: exact;
        }
        actions = {
            capAllow_forward;
            drop;
        }

        default_action = drop;
    }

    apply {
        @atomic{
            // if cases for all packet types and
            if(hdr.fractos_cmd_type == fractos_cmd_type.CapDelegate) {

            }

            if(hdr.fractos_cmd_type == fractos_cmd_type.RequestInvoke) {
                cap_table.apply();
            }
        }
    }
}