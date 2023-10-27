/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "src/packet_types.p4"

struct metadata {
    bit<14> ecmp_select;
}

parser Parse(packet_in packet,
            out headers hdr,
            inout metadata meta,
            inout standard_metadata_t standard_metadata) {
    state start {
        transition pasrse_ethernet;
    }

    state pasrse_ethernet {
        packet.extract(hdr.ethernet);

        transition select(hdr.ethernet.etherType) {
            EtherType.IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
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
        packet.extract(hdr.udp);
        transition parse_fractos_common_header;
    }

    state parse_fractos_common_header {
        packet.extract(hdr.fractos_header);
        transition select(hdr.fractos_header.cmd) {
            fractos_cmd_type.Nop: parse_fractos_nop;
            default: accept;
        }
    }

    state parse_fractos_nop {
        packet.extract(hdr.request.nop);
        transition accept;
    }
}

control ChecksumVerification(inout headers hdr, inout metadata meta) {
    apply {}
}

control deparse(packet_out packet, in headers h) {
    apply {
        packet.emit(h);
    }
}

control ing (inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }
    action drop() {
        mark_to_drop(standard_metadata);
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



control ChecksumCompute(inout headers hdr, inout metadata meta) {
       apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr 
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

control egres(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    action drop() { 
        mark_to_drop(standard_metadata);
    }

    table egress_tab {
        key =  { 
            hdr.ipv4.dstAddr : lpm;
        }
        actions = {
            drop;
        }
        size = 1024;
    }

    apply {
      egress_tab.apply();  
    }
}

V1Switch(
    Parse(),
    ChecksumVerification(),
    ing(),
    egres(),
    ChecksumCompute(),
    deparse()
) main;
