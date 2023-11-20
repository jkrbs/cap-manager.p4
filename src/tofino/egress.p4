#include "packet_types.p4"


struct egress_metadata_t {}


control Egress(inout headers hdr,
    inout egress_metadata_t                         meta,
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_dport_md) {
    action drop() {
    }

    // table egress_drop_tab {
    //     key =  {
    //         hdr.ipv4.dstAddr : lpm;
    //     }
    //     actions = {
    //         drop;
    //     }
    //     size = 1024;
    // }

    apply {
    //   egress_drop_tab.apply();
    }
}

struct egress_headers_t {
    ethernet_t ethernet;
    ipv4_t ipv4_egress;
}

parser EgressParser(packet_in      pkt,
    out headers hdr,
    out egress_metadata_t         meta) {

        state start {
            transition parse_ethernet;
        }

        state parse_ethernet {
            pkt.extract(hdr.ethernet);
            transition select(hdr.ethernet.etherType) {
                EtherType.IPV4:  parse_ipv4_egress;
                default: accept;
            }
        }

        state parse_ipv4_egress {
            pkt.extract(hdr.ipv4);
            transition accept;
        }
    }

control EgressDeparser(packet_out packet, inout headers h, in egress_metadata_t meta) {
    apply {
        packet.emit(h);
    }
}