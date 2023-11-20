#include <core.p4>
#include <tna.p4>
#include "packet_types.p4"


struct ingress_metadata_t {
    bit<1> drop;
}

parser IngressParser(packet_in      pkt,
    out headers hdr,
    out ingress_metadata_t         meta,
    out ingress_intrinsic_metadata_t  ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);

        transition select(hdr.ethernet.etherType) {
            EtherType.IPV4: parse_ipv4;
            EtherType.ARP: parse_arp;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IPv4Protocols.TCP: parse_tcp;
            IPv4Protocols.UDP: parse_udp;
            default: accept;
        }
    }

    state parse_arp {
        transition accept;
    }

    state parse_tcp {
        transition reject;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition parse_fractos_common_header;
    }

    state parse_fractos_common_header {
        pkt.extract(hdr.fractos);
        transition select(hdr.fractos.cmd) {
            fractos_cmd_type.Nop: parse_fractos_nop;
            fractos_cmd_type.InsertCap: parse_fractos_insert_cap;
            fractos_cmd_type.RequestCreate: parse_fractos_request_create;

            fractos_cmd_type.RequestInvoke: parse_request_invoke;
            fractos_cmd_type.CapInvalid: parse_cap_invalid;
            fractos_cmd_type.RequestResponse: parse_request_response;
            fractos_cmd_type.CapRevoke: parse_cap_revoke;
            default: accept;
        }
    }

    state parse_fractos_request_create {
        pkt.extract(hdr.request_create);
        transition accept;
    }

    state parse_fractos_nop {
        pkt.extract(hdr.nop);
        transition accept;
    }

    state parse_fractos_insert_cap {
        pkt.extract(hdr.cap_insert);
        transition accept;
    }

    state parse_request_invoke {
        pkt.extract(hdr.request_invoke);
        transition accept;
    }

    state parse_cap_invalid {
        pkt.extract(hdr.cap_invalid);
        transition accept;
    }

    state parse_request_response {
        pkt.extract(hdr.request_response);
        transition accept;
    }

    state parse_cap_revoke {
        pkt.extract(hdr.cap_revoke);
        transition accept;
    }
}

control Ingress(
    /* User */
    inout headers hdr,
    inout ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md) {
    
    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }


    action invalidate_cap() {
        ig_tm_md.copy_to_cpu = 1;
    }

    action delegate() {
        ig_tm_md.copy_to_cpu = 1;
    }


    // Cap exists and is valid
    action capAllow_forward(MacAddr_t dstAddr, PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 1;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = 0xffffffffff;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    // Cap exists and is valid
    action arp_forward(PortId_t port) {
        ig_tm_md.bypass_egress = 1;
        ig_tm_md.mcast_grp_a = 0x8000;
        ig_tm_md.ucast_egress_port = port;
    }

    // Cap is invalid. Notify request issuer about dropping the packets
    action capRevoked() {
        meta.drop = 1;

        ig_tm_md.bypass_egress = 1; // TODO change dest for sender to notify sender

        ig_tm_md.ucast_egress_port = 68; // packet gen port on tofino 1
        //TODO send msg via packet generator to originating host
    }


    action drop() {
        meta.drop = 1;
    }

    table routing {
        key = {
            hdr.ipv4.dstAddr: exact;
        }

        actions = {
            drop;
            capAllow_forward;
        }

        default_action = drop;

        const entries = {
            0xa000001: capAllow_forward(0xcec6b6ab6a66,8);
            0xa000003: capAllow_forward(0xe245f2409ed2,9);
        }
    }

    table cap_table {
        key = {
            hdr.fractos.cap_id: exact @name("cap_id");
            hdr.ipv4.srcAddr: exact @name("src_addr");
        }
        actions = {
            capAllow_forward;
            drop;
            capRevoked;
        }

        default_action = capAllow_forward(0xffffffffffff, 64);
    }

    apply {
        @atomic{
            meta.drop = 0;
            if (hdr.ethernet.etherType == EtherType.ARP) {
                if (ig_intr_md.ingress_port == 9) {
                    arp_forward(8);
                }
                if (ig_intr_md.ingress_port == 8) {
                    arp_forward(9);
                }
            }

            else if(hdr.ethernet.etherType == EtherType.IPV4 && hdr.ethernet.isValid()) {
                // if cases for all packet types and
                if ((hdr.udp.dstPort == 1234 || hdr.udp.dstPort == 2324) && hdr.ipv4.isValid() && hdr.udp.isValid()) {
                    if(hdr.fractos.cmd == fractos_cmd_type.InsertCap) {
                        delegate();
                    } else if(hdr.fractos.cmd == fractos_cmd_type.Nop) {
                        // handle Nop Case
                        routing.apply();
                    } else if(hdr.fractos.cmd == fractos_cmd_type.RequestInvoke) {
                        cap_table.apply();    
                    }
                } else {
                    routing.apply();
                }
            }

            else {
                if (ig_intr_md.ingress_port == 8) {
                    arp_forward(9);
                }
                if (ig_intr_md.ingress_port == 9) {
                    arp_forward(8);
                }
            }
        }  
    }

}
control IngressDeparser(packet_out                 pkt,
    /* User */
    inout headers hdr,
    in    ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md) {
    apply {
        pkt.emit(hdr);
    }
}