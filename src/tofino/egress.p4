#include "packet_types.p4"
#include "mirror.p4"


struct egress_metadata_t {
    inthdr_h           inthdr;
    bridge_h           bridge;
    MirrorId_t         mirror_session;
    bool               ing_mirrored;
    bool               egr_mirrored;
    ing_port_mirror_h  ing_port_mirror;
    egr_port_mirror_h  egr_port_mirror;
    header_type_t      mirror_header_type;
    header_info_t      mirror_header_info;
    MirrorId_t         egr_mirror_session;
    bit<16>            egr_mirror_pkt_length;
}
parser EgressParser(packet_in        pkt,
    /* User */
    out egress_headers_t          hdr,
    out egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        meta.mirror_session        = 0;
        meta.ing_mirrored          = false;
        meta.egr_mirrored          = false;
        meta.mirror_header_type    = 0;
        meta.mirror_header_info    = 0;
        meta.egr_mirror_session    = 0;
        meta.egr_mirror_pkt_length = 0;

        pkt.extract(eg_intr_md);
        meta.inthdr = pkt.lookahead<inthdr_h>();

        transition select(meta.inthdr.header_type, meta.inthdr.header_info) {
            ( HEADER_TYPE_BRIDGE,         _ ) :
                           parse_bridge;
            ( HEADER_TYPE_MIRROR_INGRESS, (header_info_t)ING_PORT_MIRROR ):
                           parse_ing_port_mirror;
            ( HEADER_TYPE_MIRROR_EGRESS,  (header_info_t)EGR_PORT_MIRROR ):
                           parse_egr_port_mirror;
            default : reject;
        }
    }

    state parse_bridge {
        pkt.extract(meta.bridge);
        transition accept;
    }

    state parse_ing_port_mirror {
        pkt.extract(meta.ing_port_mirror);
        meta.ing_mirrored   = true;
        meta.mirror_session = meta.ing_port_mirror.mirror_session;
        transition accept;
    }

    state parse_egr_port_mirror {
        pkt.extract(meta.egr_port_mirror);
        meta.egr_mirrored   = true;
        meta.mirror_session = meta.egr_port_mirror.mirror_session;
        transition accept;
    }

}

control Egress(inout egress_headers_t hdr,
    inout egress_metadata_t                         meta,
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_dport_md) {
       action just_send() {}

#ifndef DIRTY_CPU_PADDING
#define CPU_PAD(N, field) hdr.to_cpu.pad##N = 0; field
#else
#define CPU_PAD(N, field) field
#endif

    action send_to_cpu(bit<48> dst_mac, bit<48>src_mac) {
        hdr.cpu_ethernet.setValid();
        hdr.cpu_ethernet.dstAddr   = dst_mac;
        hdr.cpu_ethernet.srcAddr   = src_mac;
        hdr.cpu_ethernet.etherType = EtherType.TO_CPU;

        hdr.to_cpu.setValid();
        hdr.to_cpu.header_type = meta.inthdr.header_type;
        hdr.to_cpu.header_info = meta.inthdr.header_info;
    }

    action send_to_cpu_ing_mirror(bit<48> dst_mac, bit<48>src_mac) {
        send_to_cpu(dst_mac, src_mac);

                    hdr.to_cpu.ingress_port          = (P_PortId_t)
                                   meta.ing_port_mirror.ingress_port;
                    hdr.to_cpu.egress_port           = 0;
                    hdr.to_cpu.mirror_session        = (P_MirrorId_t)
                                    meta.ing_port_mirror.mirror_session;
                    hdr.to_cpu.pkt_length             = 0;
                    hdr.to_cpu.ingress_mac_tstamp     =
                                    meta.ing_port_mirror.ingress_mac_tstamp;
                    hdr.to_cpu.ingress_global_tstamp  =
                                    meta.ing_port_mirror.ingress_global_tstamp;
                    hdr.to_cpu.egress_global_tstamp   = 0;
                    hdr.to_cpu.mirror_global_tstamp   =
                                    eg_prsr_md.global_tstamp;

        CPU_PAD( 3, hdr.to_cpu.enq_qdepth)            = 0;
        CPU_PAD( 4, hdr.to_cpu.enq_congest_stat)      = 0;
        CPU_PAD( 6, hdr.to_cpu.deq_qdepth)            = 0;
        CPU_PAD( 7, hdr.to_cpu.deq_congest_stat)      = 0;
                    hdr.to_cpu.app_pool_congest_stat  = 0;
                    hdr.to_cpu.egress_qid             = 0;
        CPU_PAD(10, hdr.to_cpu.egress_cos)            = 0;
        CPU_PAD(11, hdr.to_cpu.deflection_flag)       = 0;
    }

    action send_to_cpu_egr_mirror(bit<48> dst_mac, bit<48>src_mac) {
        send_to_cpu(dst_mac, src_mac);

                    hdr.to_cpu.ingress_port           = (P_PortId_t)
                                    meta.egr_port_mirror.ingress_port;
                    hdr.to_cpu.egress_port            = (P_PortId_t)
                                    meta.egr_port_mirror.egress_port;
                    hdr.to_cpu.mirror_session         = (P_MirrorId_t)
                                    meta.egr_port_mirror.mirror_session;
                    hdr.to_cpu.pkt_length             =
                                    meta.egr_port_mirror.pkt_length;
              hdr.to_cpu.ingress_mac_tstamp     =
                                    meta.egr_port_mirror.ingress_mac_tstamp;
                    hdr.to_cpu.ingress_global_tstamp  =
                                    meta.egr_port_mirror.ingress_global_tstamp;
                    hdr.to_cpu.egress_global_tstamp   =
                                    meta.egr_port_mirror.egress_global_tstamp;
                    hdr.to_cpu.mirror_global_tstamp   =
                                    eg_prsr_md.global_tstamp;
        CPU_PAD( 3, hdr.to_cpu.enq_qdepth)            = 0;
        CPU_PAD( 4, hdr.to_cpu.enq_congest_stat)      = 0;
        CPU_PAD( 6, hdr.to_cpu.deq_qdepth)            = 0;
        CPU_PAD( 7, hdr.to_cpu.deq_congest_stat)      = 0;
                    hdr.to_cpu.app_pool_congest_stat  = 0;
                    hdr.to_cpu.egress_qid             = 0;
        CPU_PAD(10, hdr.to_cpu.egress_cos)            = 0;
        CPU_PAD(11, hdr.to_cpu.deflection_flag)       = 0;
          }


    action acl_mirror(MirrorId_t mirror_session) {
        eg_dprsr_md.mirror_type = EGR_PORT_MIRROR;

        /*
         * Older versions of the compiler require the programmer to
         * initialize eg_dprsr_md.mirror_io_select manually. Newer versions
         * automatically initialize that field for Tofino-compatible behavior
         */
#if COMPILER_VERSION <= PACK_VERSION(9,7,0)
        #if __TARGET_TOFINO__ > 1
        eg_dprsr_md.mirror_io_select = 1;
        #endif
#endif
        meta.mirror_header_type     = HEADER_TYPE_MIRROR_EGRESS;
        meta.mirror_header_info     = (header_info_t)EGR_PORT_MIRROR;
        meta.egr_mirror_session     = mirror_session;

        /*
         * An interesting (and a little counter-intuitive) property of
         * eg_intr_md.pkt_length is that it reflects the length of the
         * "normal" (i.e. not mirrored) packet as it was at ingress, i.e.,
         * even if any modifications have been done to the packet (such
         * as prepending the bridge header), they will not be reflected
         * in eg_intr_md.pkt_length.
         *
         * Fortunately, this is precisely what we want in this case!
         */
        meta.egr_mirror_pkt_length  = eg_intr_md.pkt_length;
    }

    apply {
       acl_mirror(0);
    }
}

control EgressDeparser(packet_out pkt,
    /* User */
    inout egress_headers_t                       hdr,
    in    egress_metadata_t                      meta,
    /* Intrinsic */
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md,
    in    egress_intrinsic_metadata_t               eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t   eg_prsr_md)
{
    Mirror() egr_port_mirror;
    apply {
        /*
         * If there is a mirror request, create a clone.
         * Note: Mirror() externs emits the provided header, but also
         * appends the ORIGINAL ingress packet after those
         */
        if (eg_dprsr_md.mirror_type == EGR_PORT_MIRROR) {
            egr_port_mirror.emit<egr_port_mirror_h>(
                meta.egr_mirror_session,
                {
                    meta.mirror_header_type,
                    meta.mirror_header_info,
                    PAD(meta.bridge.ingress_port),
                    PAD(eg_intr_md.egress_port),
                    PAD(meta.egr_mirror_session),
                    meta.egr_mirror_pkt_length,
#ifndef TOFINO_TELEMETRY
                    meta.bridge.ingress_mac_tstamp,
                    meta.bridge.ingress_global_tstamp,
                    eg_prsr_md.global_tstamp
#else
                    meta.bridge.ingress_mac_tstamp,
                    eg_prsr_md.global_tstamp,
                    PAD(eg_intr_md.enq_qdepth),
                    PAD(eg_intr_md.enq_congest_stat),
                    PAD(eg_intr_md.deq_qdepth),
                    PAD(eg_intr_md.deq_congest_stat),
                    eg_intr_md.app_pool_congest_stat,
                    PAD(eg_intr_md.egress_qid),
                    PAD(eg_intr_md.egress_cos)
#endif
                });
        }

        pkt.emit(hdr);
    }
}
