/* -*- P4_16 -*- */
#ifndef __PACKET_TYPES_H__
#define __PACKET_TYPES_H__

#include <core.p4>

#include "config.p4"

const PortId_t CPU_PORT = 64;

enum bit<16> EtherType {
  VLAN      = 0x8100,
  QINQ      = 0x9100,
  MPLS      = 0x8847,
  IPV4      = 0x0800,
  ARP       = 0x0806,
  IPV6      = 0x86dd,
  TO_CPU    = 0xbf01
}

enum bit<8> IPv4Protocols {
    TCP = 6,
    UDP = 17
}

const bit<16> ARP_HTYPE = 0x0001;    // Ethernet Hardware type is 1
const bit<16> ARP_PTYPE = EtherType.IPV4; // Protocol used for ARP is IPV4
const bit<8>  ARP_HLEN  = 6;         // Ethernet address size is 6 bytes
const bit<8>  ARP_PLEN  = 4;         // IP address size is 4 bytes
const bit<16> ARP_REQ = 1;           // Operation 1 is request
const bit<16> ARP_REPLY = 2;         // Operation 2 is reply

typedef bit<48> MacAddr_t;

header ethernet_t {
    MacAddr_t dstAddr;
    MacAddr_t srcAddr;
    EtherType etherType;
}

header arp_t {
  bit<16>   h_type;
  bit<16>   p_type;
  bit<8>    h_len;
  bit<8>    p_len;
  bit<16>   op_code;
  MacAddr_t src_mac;
  bit<32> src_ip;
  MacAddr_t dst_mac;
  bit<32> dst_ip;
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

enum bit<32> fractos_cmd_type {
        Nop = 0x0,
        CapGetInfo = 0x01000000,
        CapIsSame = 0x02000000,
        CapDiminish = 0x03000000,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        CapClose = 0x05000000,
        CapRevoke = 0x06000000,
        CapInvalid = 0x07000000,

        MemoryCopy = 0x0a000000,
        MemoryCopyResponse = 0x0b000000,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        RequestCreate = 0x0d000000,
        RequestInvoke = 0x0e000000,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        RequestReceive = 0x10000000,
        RequestResponse = 0x11000000,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        None = 0x20000000, // None is used as default value

        //P4 Implementation specific OP Codes
        InsertCap = 0x40000000
}


struct IpAddress {
    bit<32> address;
    bit<32> netmask;
    bit<16> port;
}

header fractos_common_header_t {
    bit<64> size;
    bit<32> stream_id;
    fractos_cmd_type cmd;
    bit<64> cap_id;
}

header fractos_nop_request_t {
    bit<64> info;
}

header fractos_request_create_header_t {
}

header fractos_request_invoke_header_t {
}

header fractos_cap_invalid_header_t {
}

header fractos_request_response_header_t {
    bit<64> response_code;
}

header fractos_insert_cap_header_t {
    IpAddress cap_owner_ip;
    bit<64> cap_id;
    bit<8> cap_type;
    IpAddress object_owner;
}

header fractos_revoke_cap_header_t {
    IpAddress cap_owner_ip;
    bit<64> cap_id;
}

typedef bit<8>  pkt_type_t;
const pkt_type_t PKT_TYPE_NORMAL = 1;
const pkt_type_t PKT_TYPE_MIRROR = 2;

#if __TARGET_TOFINO__ == 1
typedef bit<3> mirror_type_t;
#else
typedef bit<4> mirror_type_t;
#endif
const mirror_type_t MIRROR_TYPE_I2E = 1;
const mirror_type_t MIRROR_TYPE_E2E = 2;

header empty_header_t {}
struct empty_metadata_t {}

header mirror_bridged_metadata_h {
    pkt_type_t pkt_type;
    @flexible bool do_egr_mirroring;  //  Enable egress mirroring
    @flexible MirrorId_t egr_mir_ses;   // Egress mirror session ID
}

header mirror_h {
    pkt_type_t  pkt_type;
}

struct headers {
    mirror_bridged_metadata_h bridged_md;
    ethernet_t ethernet;
    ipv4_t ipv4;
    arp_t arp;
    udp_t udp;
    fractos_common_header_t fractos;

    fractos_nop_request_t nop;
    fractos_request_create_header_t request_create;
    fractos_request_invoke_header_t request_invoke;
    fractos_cap_invalid_header_t cap_invalid;
    fractos_request_response_header_t request_response;

    fractos_insert_cap_header_t cap_insert;
    fractos_revoke_cap_header_t cap_revoke;
}

#endif