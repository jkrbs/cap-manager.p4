#ifndef __meta_p4__
#define __meta_p4__

struct ingress_metadata_t {
    bool do_ing_mirroring;  // Enable ingress mirroring
    bool do_egr_mirroring;  // Enable egress mirroring
    MirrorId_t ing_mir_ses;   // Ingress mirror session ID
    MirrorId_t egr_mir_ses;   // Egress mirror session ID
    pkt_type_t pkt_type;
    bool drop;
}

#endif