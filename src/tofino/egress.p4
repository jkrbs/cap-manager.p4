#include "packet_types.p4"
#include "util.p4"

struct egress_metadata_t {
    bit<1> do_ing_mirroring;  // Enable ingress mirroring
    bit<1> do_egr_mirroring;  // Enable egress mirroring
    MirrorId_t ing_mir_ses;   // Ingress mirror session ID
    MirrorId_t egr_mir_ses;   // Egress mirror session ID
    pkt_type_t pkt_type;
}
parser EgressParser(packet_in        pkt,
    /* User */
    out headers          hdr,
    out egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    TofinoEgressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, eg_intr_md);
        transition parse_metadata;
    }

    state parse_metadata {
        mirror_h mirror_md = pkt.lookahead<mirror_h>();
        transition select(mirror_md.pkt_type) {
            PKT_TYPE_MIRROR : parse_mirror_md;
            PKT_TYPE_NORMAL : parse_bridged_md;
            default : accept;
        }
    }

    state parse_bridged_md {
        pkt.extract(hdr.bridged_md);
        transition parse_ethernet;
    }

    state parse_mirror_md {
        mirror_h mirror_md;
        pkt.extract(mirror_md);
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
        transition accept;
    }

}

// ---------------------------------------------------------------------------
// Egress Deparser
// ---------------------------------------------------------------------------
control EgressDeparser(
        packet_out pkt,
        inout headers hdr,
        in egress_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {

    Mirror() mirror;
    Checksum() ipv4_checksum;
    apply {
        hdr.ipv4.hdrChecksum = ipv4_checksum.update(
            { 
              hdr.ipv4.version,
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
        });

        if (eg_dprsr_md.mirror_type == MIRROR_TYPE_E2E) {
            mirror.emit<mirror_h>(eg_md.egr_mir_ses, {eg_md.pkt_type});
        }

        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
    }
}

// ---------------------------------------------------------------------------
// Switch Egress MAU
// ---------------------------------------------------------------------------
control Egress(
        inout headers hdr,
        inout egress_metadata_t eg_md,
        in    egress_intrinsic_metadata_t                 eg_intr_md,
        in    egress_intrinsic_metadata_from_parser_t     eg_prsr_md,
        inout egress_intrinsic_metadata_for_deparser_t    eg_dprsr_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {

    action set_mirror() {
        eg_md.egr_mir_ses = hdr.bridged_md.egr_mir_ses;
        eg_md.pkt_type = PKT_TYPE_MIRROR;
        eg_dprsr_md.mirror_type = MIRROR_TYPE_E2E;
#if __TARGET_TOFINO__ != 1
        eg_dprsr_md.mirror_io_select = 1; // E2E mirroring for Tofino2 & future ASICs
#endif
    }

    apply {
        set_mirror();
    }
}