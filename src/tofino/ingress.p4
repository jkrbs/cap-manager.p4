#include <core.p4>
#include <tna.p4>
#include "packet_types.p4"
#include "config.p4"
#include "arp_table.p4"

#include "ingress_parser.p4"

#define CPU_MIRROR_SESSION_ID                   128

control Ingress(
    /* User */
    inout headers hdr,
    inout ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md) {
    
    action drop() {
        meta.drop = true;
    }
    

    action set_mirror_type() {
        ig_dprsr_md.mirror_type = MIRROR_TYPE_E2E;
        meta.pkt_type = PKT_TYPE_MIRROR;
        hdr.ipv4.hdrChecksum = 0x0;
    }

    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }


    action invalidate_cap() {
        ig_tm_md.copy_to_cpu = 1;
    }

    action set_normal_pkt() {
        hdr.bridged_md.setValid();
        hdr.bridged_md.pkt_type = PKT_TYPE_NORMAL;
    }

    action set_md(PortId_t dest_port, bool ing_mir, MirrorId_t ing_ses, bool egr_mir, MirrorId_t egr_ses) {
        ig_tm_md.ucast_egress_port = dest_port;
        meta.do_ing_mirroring = ing_mir;
        meta.ing_mir_ses = ing_ses;
        hdr.bridged_md.do_egr_mirroring = egr_mir;
        hdr.bridged_md.egr_mir_ses = egr_ses;
        hdr.ethernet.srcAddr = CONTROLLER_SWITCHPORT_MAC;
        hdr.ethernet.dstAddr = CONTROLLER_MAC;
        hdr.ipv4.dstAddr = CONTROLLER_ADDRESS;
        hdr.ipv4.srcAddr = CONTROLLER_SWITCH_IP;
        hdr.ipv4.hdrChecksum = 0;
        hdr.udp.checksum = 0;
        hdr.udp.dstPort = CONTROLLER_PORT;

        ig_tm_md.bypass_egress = 0;
    }

    table  mirror_fwd {
        key = {
            ig_intr_md.ingress_port  : exact;
        }

        actions = {
            set_md;
        }

        size = 512;
    }

    // action delegate(MirrorId_t mirror_session) {
    //     //ig_tm_md.copy_to_cpu = 1;
    //     //ig_tm_md.bypass_egress = 0; // TODO change dest for sender to notify sender


    // }


    // Cap exists and is valid
    action capAllow_forward(MacAddr_t dstAddr, MacAddr_t srcAddr, PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        // ig_tm_md.bypass_egress = 1;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ethernet.srcAddr = srcAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    // Cap exists and is valid
    action arp_forward(PortId_t port) {
        ig_tm_md.bypass_egress = 0;
        ig_tm_md.ucast_egress_port = port;
    }

    // Cap is invalid. Notify request issuer about dropping the packets
    action capRevoked() {
        meta.drop = true;

        // ig_tm_md.bypass_egress = 0; // TODO change dest for sender to notify sender

        ig_tm_md.ucast_egress_port = 64; // packet gen port on tofino 1
        //TODO send msg via packet generator to originating host
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
        size = 8192;
        const entries = {
            0xa000102: capAllow_forward(0x1a507bd705e0, 0x000000000100, 1);
            0xa000202: capAllow_forward(0x2afee6c639ca, 0x000000000101, 32);
            0xa000902: capAllow_forward(CONTROLLER_MAC, CONTROLLER_SWITCHPORT_MAC, 64);
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
        size = 8192;
        default_action = capAllow_forward(CONTROLLER_MAC, CONTROLLER_SWITCHPORT_MAC, 64);
    }

    ArpTable() arp;
    
    apply {
        meta.drop = false;
        if (hdr.ethernet.etherType == EtherType.ARP) {
            if (hdr.arp.isValid()){
                arp.apply(hdr, meta, ig_intr_md, ig_tm_md);
            }
        }

        else if(hdr.ethernet.etherType == EtherType.IPV4 && hdr.ethernet.isValid()) {
            // if cases for all packet types and
            if ((hdr.udp.dstPort == 1234 || hdr.udp.dstPort == 2324)) {
                if(hdr.fractos.cmd == fractos_cmd_type.InsertCap) {
                    if(hdr.ipv4.dstAddr != CONTROLLER_ADDRESS && hdr.ipv4.srcAddr != CONTROLLER_ADDRESS) {
                        //if (ig_intr_md.resubmit_flag == 0) {
                        mirror_fwd.apply();
                        //}

                        if (meta.do_ing_mirroring == true) {
                            set_mirror_type();
                        } else {
                            set_normal_pkt();
                        }
                    }
                } else if(hdr.fractos.cmd == fractos_cmd_type.Nop) {
                    // handle Nop Case
                    cap_table.apply();
                } else if(hdr.fractos.cmd == fractos_cmd_type.RequestInvoke) {
                    cap_table.apply();    
                }

            } else {
                routing.apply();
            }
        }  
    }
}
control IngressDeparser(
        packet_out pkt,
        inout headers hdr,
        in ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    Mirror() mirror;
    
    Checksum() ipv4_checksum;
    Checksum() udp_checksum;
    
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
        if (ig_dprsr_md.mirror_type == MIRROR_TYPE_I2E) {
            mirror.emit<mirror_h>(ig_md.ing_mir_ses, {ig_md.pkt_type});
        }

        pkt.emit(hdr);
    }
}
