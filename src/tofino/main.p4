/* -*- P4_16 -*- */
#include <core.p4>
#include <tna.p4>

struct ingress_metadata_t {
    bit<1> drop;
}

enum bit<16> EtherType {
  VLAN      = 0x8100,
  QINQ      = 0x9100,
  MPLS      = 0x8847,
  IPV4      = 0x0800,
  IPV6      = 0x86dd
}

enum bit<8> IPv4Protocols {
    TCP = 6,
    UDP = 17
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    EtherType etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> len;
    bit<16> checksum;
}

header fractos_header_t {
    bit<32> size;
    bit<32> cmd;
    bit<64> id;
}

header fractos_nop_request_t {
    bit<64> info;
}

header fractos_request_create_header_t {
}

header fractos_request_types_t {
    //fractos_request_create_header_t request_create;
//    fractos_nop_request_t nop;
    // TODO This should be a header union over all possible FractOS packets
}


enum bit<32> fractos_cmd_type {
    Nop = 0,
    CapGetInfo = 1,
    CapIsSame = 2,
    CapDiminish = 3,
    /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
    CapClose = 5,
    CapRevoke = 6,
    /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
    RequestCreate = 13,
    RequestInvoke = 14,
    /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
    RequestReceive = 16,
    /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
    None = 32 // None is used as default value
}

header fractos_common_header_t {
    fractos_cmd_type cmd;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t ipv4;
    udp_t udp;
    fractos_common_header_t fractos_header;
//    fractos_request_types_t request;
}


parser IngressParser(packet_in      pkt,
    out headers hdr,
    out ingress_metadata_t         meta,
    out ingress_intrinsic_metadata_t  ig_intr_md) {
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);

        transition select(hdr.ethernet.etherType) {
            EtherType.IPV4: parse_ipv4;
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

    state parse_tcp {
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition parse_fractos_common_header;
    }

    state parse_fractos_common_header {
        pkt.extract(hdr.fractos_header);
        transition select(hdr.fractos_header.cmd) {
            fractos_cmd_type.Nop: accept;
//            fractos_cmd_type.Nop: parse_fractos_nop;

            default: accept;
        }
    }

//    state parse_fractos_nop {
//
//        pkt.extract(hdr.request.nop);
//        transition accept;
//    }
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
    action drop() {
        meta.drop = 1;
    }

    table ingress_match {
        key =  {
            hdr.ipv4.dstAddr : lpm;
        }
        actions = {
            rewrite_mac;
            drop;
        }
        size = 1024;
    }

    apply {
        ingress_match.apply();
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

struct egress_metadata_t {}


control Egress(inout headers hdr,
    inout egress_metadata_t                         meta,
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_dport_md) {
    action drop() {
    }

    table egress_drop_tab {
        key =  {
            hdr.ipv4.dstAddr : lpm;
        }
        actions = {
            drop;
        }
        size = 1024;
    }

    apply {
      egress_drop_tab.apply();
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

Pipeline (
 IngressParser(),
 Ingress(),
 IngressDeparser(),
 EgressParser(),
 Egress(),
 EgressDeparser()
) pipe;

Switch (pipe) main;
