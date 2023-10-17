/* -*- P4_16 -*- */

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

header_union fractos_requests_types_t {
    fractos_request_create_header_t request_create ;
    fractos_nop_request_t nop;
}


enum bit<64> fractos_cmd_type {
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

struct fractos_request_t {
    fractos_cmd_type cmd;
    fractos_requests_types_t request;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t ipv4;
    udp_t udp;
    fractos_request_t request;
}
