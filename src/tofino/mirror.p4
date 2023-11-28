/* -*- P4_16 -*- */
#ifndef __MIRROR_H__
#define __MIRROR_H__

#ifndef FLEXIBLE_HEADERS
#define PAD(field)  0, field
#else
#define PAD(field)  field
#endif

#ifndef DIRTY_CPU_PADDING
#define PADDING
#else
#define PADDING @padding
#endif
/*
 * Portable Types for PortId and MirrorID that do not depend on the target
 */
typedef bit<16> P_PortId_t;
typedef bit<16> P_MirrorId_t;
typedef bit<8>  P_QueueId_t;

#if __TARGET_TOFINO__ == 1
typedef bit<7> PortId_Pad_t;
typedef bit<6> MirrorId_Pad_t;
typedef bit<3> QueueId_Pad_t;
#define MIRROR_DEST_TABLE_SIZE 256
#elif __TARGET_TOFINO__ == 2
typedef bit<7> PortId_Pad_t;
typedef bit<8> MirrorId_Pad_t;
typedef bit<1> QueueId_Pad_t;
#define MIRROR_DEST_TABLE_SIZE 256
#else
#error Unsupported Tofino target
#endif


/*** Internal Headers ***/

typedef bit<4> header_type_t;
typedef bit<4> header_info_t;

const header_type_t HEADER_TYPE_BRIDGE         = 0xB;
const header_type_t HEADER_TYPE_MIRROR_INGRESS = 0xC;
const header_type_t HEADER_TYPE_MIRROR_EGRESS  = 0xD;
const header_type_t HEADER_TYPE_RESUBMIT       = 0xA;


#define INTERNAL_HEADER         \
    header_type_t header_type;  \
    header_info_t header_info

header inthdr_h {
    INTERNAL_HEADER;
}

/* Bridged metadata */
header bridge_h {
    INTERNAL_HEADER;

#ifdef FLEXIBLE_HEADERS
    @flexible     PortId_t ingress_port;
    @flexible     bit<48>  ingress_mac_tstamp;
    @flexible     bit<48>  ingress_global_tstamp;
#else
    @padding PortId_Pad_t    pad0; PortId_t   ingress_port;
                                   bit<48>    ingress_mac_tstamp;
                                   bit<48>    ingress_global_tstamp;
#endif
}

/* Ingress mirroring information */
const MirrorType_t ING_PORT_MIRROR = 3;
const MirrorType_t EGR_PORT_MIRROR = 5;

header ing_port_mirror_h {
    INTERNAL_HEADER;

#ifdef FLEXIBLE_HEADERS
    @flexible     PortId_t    ingress_port;
    @flexible     MirrorId_t  mirror_session;
    @flexible     bit<48>     ingress_mac_tstamp;
    @flexible     bit<48>     ingress_global_tstamp;
#else
    @padding PortId_Pad_t    pad0; PortId_t    ingress_port;
    @padding MirrorId_Pad_t  pad1; MirrorId_t  mirror_session;
                                   bit<48>     ingress_mac_tstamp;
                                   bit<48>     ingress_global_tstamp;
#endif
}

header egr_port_mirror_h {
    INTERNAL_HEADER;                                                  /* 1 */

#ifdef FLEXIBLE_HEADERS
    @flexible  PortId_t    ingress_port;
    @flexible  PortId_t    egress_port;
    @flexible  MirrorId_t  mirror_session;
    @flexible  bit<16>     pkt_length;

#ifndef TOFINO_TELEMETRY
    @flexible  bit<48>     ingress_mac_tstamp;
    @flexible  bit<48>     ingress_global_tstamp;
    @flexible  bit<48>     egress_global_tstamp;
#else
    @flexible  bit<48>     ingress_mac_tstamp;
    @flexible  bit<48>     egress_global_tstamp;
    /* The fields below won't work on the model */
        @flexible  bit<19>     enq_qdepth;
    @flexible  bit<2>      enq_congest_stat;
    @flexible  bit<19>     deq_qdepth;
    @flexible  bit<2>      deq_congest_stat;
    @flexible  bit<8>      app_pool_congest_stat;
    @flexible  QueueId_t   egress_qid;
    @flexible  bit<3>      egress_cos;
#endif

#else /* Fixed Headers */                                            /* Bytes */
    @padding PortId_Pad_t    pad0; PortId_t    ingress_port;          /*  2 */
    @padding PortId_Pad_t    pad1; PortId_t    egress_port;           /*  2 */
    @padding MirrorId_Pad_t  pad2; MirrorId_t  mirror_session;        /*  2 */
                                   bit<16>     pkt_length;            /*  2 */
#ifndef TOFINO_TELEMETRY
                                   bit<48>     ingress_mac_tstamp;    /*  6 */
                                   bit<48>     ingress_global_tstamp; /*  6 */
                                   bit<48>     egress_global_tstamp;  /*  6 */
                                                         /* 1 + 8 + 18 = 27 */
#else
                                   bit<48>     ingress_mac_tstamp;    /*  6 */
                                   bit<48>     egress_global_tstamp;  /*  6 */
    /* The fields below won't work on the model */
    @padding bit<5>         pad3;  bit<19>     enq_qdepth;            /*  3 */
    @padding bit<6>         pad4;  bit<2>      enq_congest_stat;      /*  1 */
    @padding bit<5>         pad6;  bit<19>     deq_qdepth;            /*  3 */
    @padding bit<6>         pad7;  bit<2>      deq_congest_stat;      /*  1 */
                                   bit<8>      app_pool_congest_stat; /*  1 */
    @padding QueueId_Pad_t  pad9;  QueueId_t   egress_qid;            /*  1 */
    @padding bit<5>  pad10;        bit<3>      egress_cos;            /*  1 */
#endif                                                   /* 1 + 8 + 24 = 32 */
#endif /* FLEXIBLE_HEADERS */
}

header to_cpu_h {
    INTERNAL_HEADER;
                            P_PortId_t   ingress_port;
                            P_PortId_t   egress_port;
                            P_MirrorId_t mirror_session;
                            bit<16>      pkt_length;
                            bit<48>      ingress_mac_tstamp;
                            bit<48>      ingress_global_tstamp;
                            bit<48>      egress_global_tstamp;
                            bit<48>      mirror_global_tstamp;
    /*
     * The fields below are great for telemetry, but won't work on the model.
     * However, we'll always keep them in the header to avoid changing the
     * header definition in PTF tests
     */
    PADDING  bit<5>  pad3;  bit<19>      enq_qdepth;
    PADDING  bit<6>  pad4;  bit<2>       enq_congest_stat;
    PADDING  bit<5>  pad6;  bit<19>      deq_qdepth;
    PADDING  bit<6>  pad7;  bit<2>       deq_congest_stat;
                            bit<8>       app_pool_congest_stat;
    PADDING  bit<14> pad8;  bit<18>      deq_timedelta;
                            P_QueueId_t  egress_qid;
    PADDING  bit<5>  pad10; bit<3>       egress_cos;
    PADDING  bit<7>  pad11; bit<1>       deflection_flag;
}


struct egress_headers_t {
    ethernet_t   cpu_ethernet;
    to_cpu_h     to_cpu;
}
#endif