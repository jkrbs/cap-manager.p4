#include "meta.p4"

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
        pkt.extract(hdr.arp);
        transition select(hdr.arp.op_code) {
            ARP_REQ: accept;
	        default: accept;
        }
    }

    state parse_tcp {
        transition accept;
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