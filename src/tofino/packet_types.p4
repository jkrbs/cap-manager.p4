/* -*- P4_16 -*- */
#ifndef __PACKET_TYPES_H__
#define __PACKET_TYPES_H__

#include <core.p4>

enum bit<16> EtherType {
  VLAN      = 0x8100,
  QINQ      = 0x9100,
  MPLS      = 0x8847,
  IPV4      = 0x0800,
  ARP       = 0x0806,
  IPV6      = 0x86dd
}

enum bit<8> IPv4Protocols {
    TCP = 6,
    UDP = 17
}

typedef bit<48> MacAddr_t;

header ethernet_t {
    MacAddr_t dstAddr;
    MacAddr_t srcAddr;
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

enum bit<32> fractos_cmd_type {
        Nop = 0,
        CapGetInfo = 1,
        CapIsSame = 2,
        CapDiminish = 3,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        CapClose = 5,
        CapRevoke = 6,
        CapInvalid = 7,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        RequestCreate = 13,
        RequestInvoke = 14,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        RequestReceive = 16,
        RequestResponse = 17,
        /* Gap in OPCode Numbers Caused by Packet Types Unsupported by this implementation */
        None = 32, // None is used as default value

        //P4 Implementation specific OP Codes
        InsertCap = 64
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

struct headers {
    ethernet_t ethernet;
    ipv4_t ipv4;
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