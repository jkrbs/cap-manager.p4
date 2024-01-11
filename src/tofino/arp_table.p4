/**
** ARP responder is copied from here
** https://github.com/p4lang/p4pi/blob/a57a376dde6db81b70db85fcc7d37a8b839fe015/packages/p4pi-examples/bmv2/arp_icmp/arp_icmp.p4#L4
*/

#ifndef __ARP_TABLE__
#define __ARP_TABLE__

#include "meta.p4"

control ArpTable(
    /* User */
    inout headers hdr,
    inout ingress_metadata_t                      meta,
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md) {
    
    action drop() {
        meta.drop = true;
    }

    action arp_reply(MacAddr_t request_mac) {
        //update operation code from request to reply
        hdr.arp.op_code = ARP_REPLY;
        
        //reply's dst_mac is the request's src mac
        hdr.arp.dst_mac = hdr.arp.src_mac;
        
        //reply's dst_ip is the request's src ip
        hdr.arp.src_mac = request_mac;

        //reply's src ip is the request's dst ip
        hdr.arp.src_ip = hdr.arp.dst_ip;

        //update ethernet header
        hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = request_mac;

        //send it back to the same port
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
    }

    table arp_exact {
        key = {
            hdr.arp.dst_ip: exact @name("ipaddr");
        }
        actions = {
            arp_reply;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

    apply {
        arp_exact.apply();
    }
}
#endif
