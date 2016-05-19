// Copyright (c) 2016 Cornell University

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import ClientServer::*;
import Connectable::*;
import DbgDefs::*;
import DefaultValue::*;
import Ethernet::*;
import FIFO::*;
import FIFOF::*;
import FShow::*;
import GetPut::*;
import List::*;
import MatchTable::*;
import MatchTableSim::*;
import PacketBuffer::*;
import Pipe::*;
import SpecialFIFOs::*;
import StmtFSM::*;
import Utils::*;
import Vector::*;

import MainDefs::*;

typedef struct {
  RouteActionT p4_action;
  Bit#(9) action_1_arg0;
} RoutingRespT deriving (Bits, Eq);

instance DefaultValue#(RoutingRespT);
  defaultValue = unpack(0);
endinstance
instance DefaultMask#(RoutingRespT);
  defaultMask = unpack(maxBound);
endinstance

instance FShow#(RoutingRespT);
  function Fmt fshow(RoutingRespT p);
    return $format("RoutingRespT: p4_action=%h, action_1_arg0=%h", p.p4_action, p.action_1_arg0);
  endfunction
endinstance

typedef struct {
   Maybe#(Bit#(32)) dstAddr; // ethernet$dstAddr
   Maybe#(Bit#(16)) etherType; // ethernet$etherType
   Maybe#(Bit#(8))  protocol; // ipv4$protocol
   Maybe#(Bool) valid_ethernet;
   Maybe#(Bool) valid_ipv4;
   Maybe#(RouteActionT) routingtable$route;
   Maybe#(Bit#(9)) egress_port;
} MetadataT deriving (Bits, Eq);

instance DefaultValue#(MetadataT);
defaultValue =
MetadataT {
   dstAddr: tagged Invalid,
   etherType: tagged Invalid,
   protocol: tagged Invalid,
   egress_port: tagged Invalid,
   valid_ethernet: tagged Invalid,
   valid_ipv4: tagged Invalid
};
endinstance

instance FShow#(MetadataT);
   function Fmt fshow(MetadataT p);
      return $format("dstAddr=", fshow(p.dstAddr), ",")+
             $format("etherType=", fshow(p.etherType), ",")+
             $format("protocol=", fshow(p.protocol), ",")+
             $format("egress_port=", fshow(p.egress_port), ",");
   endfunction
endinstance

typedef union tagged {
   struct {
      PacketInstance pkt;
   } PacketMemRequest;

   struct {
      PacketInstance pkt;
      MetadataT meta;
   } RoutingTableRequest;

   struct {
      PacketInstance pkt;
      MetadataT meta;
   } ForwardQueueRequest;

   struct {
      PacketInstance pkt;
      MetadataT meta;
   } DefaultRequest;
} MetadataRequest deriving (Bits, Eq, FShow);

typedef union tagged {
   struct {
      PacketInstance pkt;
      MetadataT meta;
   } RoutingTableResponse;
} MetadataResponse deriving (Bits, Eq, FShow);

typedef Client#(MetadataRequest, MetadataResponse) MetadataClient;
typedef Server#(MetadataRequest, MetadataResponse) MetadataServer;

typedef union tagged {
   struct {
      PacketInstance pkt;
      Bit#(9) egress_port;
   } BBForwardRequest;
   struct {
      PacketInstance pkt;
   } BBNopRequest;
} BBRequest deriving (Bits, Eq, FShow);

typedef union tagged {
   struct {
      PacketInstance pkt;
   } BBNopResponse;
   struct {
      PacketInstance pkt;
      Bit#(9) egress_port;
   } BBForwardResponse;
} BBResponse deriving (Bits, Eq, FShow);


typedef Client#(BBRequest, BBResponse) BBClient;
typedef Server#(BBRequest, BBResponse) BBServer;

function RoutingRespT extract_RoutingRespT(Bit#(10) data);
  Vector#(10, Bit#(1)) dataVec = unpack(data);
  Vector#(1, Bit#(1)) p4_action = takeAt(1, dataVec);
  Vector#(9, Bit#(1)) action_1_arg0 = takeAt(2, dataVec);
  RoutingRespT hdr = defaultValue;
  hdr.p4_action = unpack(pack(p4_action));
  hdr.action_1_arg0 = pack(action_1_arg0);
  return hdr;
endfunction

typedef struct {
  Bit#(4) padding;
  Bit#(32) dstAddr;
} RoutingReqT deriving (Bits, Eq);

instance DefaultValue#(RoutingReqT);
  defaultValue = unpack(0);
endinstance
instance DefaultMask#(RoutingReqT);
  defaultMask = unpack(maxBound);
endinstance

instance FShow#(RoutingReqT);
  function Fmt fshow(RoutingReqT p);
    return $format("RoutingReqT: dstAddr=%h", p.dstAddr);
  endfunction
endinstance

function RoutingReqT extract_routing_req_t(Bit#(32) data);
  Vector#(32, Bit#(1)) dataVec = unpack(data);
  Vector#(32, Bit#(1)) dstAddr = takeAt(0, dataVec);
  RoutingReqT hdr = defaultValue;
  hdr.dstAddr = pack(dstAddr);
  return hdr;
endfunction

typedef struct {
  Bit#(9) ingress_port;
  Bit#(32) packet_length;
  Bit#(9) egress_spec;
  Bit#(9) egress_port;
  Bit#(32) egress_instance;
  Bit#(32) instance_type;
  Bit#(32) clone_spec;
  Bit#(5) _padding;
} StandardMetadata deriving (Bits, Eq);

instance DefaultValue#(StandardMetadata);
  defaultValue = unpack(0);
endinstance
instance DefaultMask#(StandardMetadata);
  defaultMask = unpack(maxBound);
endinstance

instance FShow#(StandardMetadata);
  function Fmt fshow(StandardMetadata p);
    return $format("StandardMetadata: ingress_port=%h, packet_length=%h, egress_spec=%h, egress_port=%h, egress_instance=%h, instance_type=%h, clone_spec=%h, _padding=%h", p.ingress_port, p.packet_length, p.egress_spec, p.egress_port, p.egress_instance, p.instance_type, p.clone_spec, p._padding);
  endfunction
endinstance

function StandardMetadata extract_standard_metadata(Bit#(160) data);
  Vector#(160, Bit#(1)) dataVec = unpack(data);
  Vector#(9, Bit#(1)) ingress_port = takeAt(0, dataVec);
  Vector#(32, Bit#(1)) packet_length = takeAt(9, dataVec);
  Vector#(9, Bit#(1)) egress_spec = takeAt(41, dataVec);
  Vector#(9, Bit#(1)) egress_port = takeAt(50, dataVec);
  Vector#(32, Bit#(1)) egress_instance = takeAt(59, dataVec);
  Vector#(32, Bit#(1)) instance_type = takeAt(91, dataVec);
  Vector#(32, Bit#(1)) clone_spec = takeAt(123, dataVec);
  Vector#(5, Bit#(1)) _padding = takeAt(155, dataVec);
  StandardMetadata hdr = defaultValue;
  hdr.ingress_port = pack(ingress_port);
  hdr.packet_length = pack(packet_length);
  hdr.egress_spec = pack(egress_spec);
  hdr.egress_port = pack(egress_port);
  hdr.egress_instance = pack(egress_instance);
  hdr.instance_type = pack(instance_type);
  hdr.clone_spec = pack(clone_spec);
  hdr._padding = pack(_padding);
  return hdr;
endfunction

typedef struct {
  Bit#(4) version;
  Bit#(4) ihl;
  Bit#(8) diffserv;
  Bit#(16) totalLen;
  Bit#(16) identification;
  Bit#(3) flags;
  Bit#(13) fragOffset;
  Bit#(8) ttl;
  Bit#(8) protocol;
  Bit#(16) hdrChecksum;
  Bit#(32) srcAddr;
  Bit#(32) dstAddr;
} Ipv4T deriving (Bits, Eq);

instance DefaultValue#(Ipv4T);
  defaultValue = unpack(0);
endinstance
instance DefaultMask#(Ipv4T);
  defaultMask = unpack(maxBound);
endinstance

instance FShow#(Ipv4T);
  function Fmt fshow(Ipv4T p);
    return $format("Ipv4T: version=%h, ihl=%h, diffserv=%h, totalLen=%h, identification=%h, flags=%h, fragOffset=%h, ttl=%h, protocol=%h, hdrChecksum=%h, srcAddr=%h, dstAddr=%h", p.version, p.ihl, p.diffserv, p.totalLen, p.identification, p.flags, p.fragOffset, p.ttl, p.protocol, p.hdrChecksum, p.srcAddr, p.dstAddr);
  endfunction
endinstance

function Ipv4T extract_ipv4_t(Bit#(160) data);
  Vector#(160, Bit#(1)) dataVec = unpack(data);
  Vector#(4, Bit#(1)) version = takeAt(0, dataVec);
  Vector#(4, Bit#(1)) ihl = takeAt(4, dataVec);
  Vector#(8, Bit#(1)) diffserv = takeAt(8, dataVec);
  Vector#(16, Bit#(1)) totalLen = takeAt(16, dataVec);
  Vector#(16, Bit#(1)) identification = takeAt(32, dataVec);
  Vector#(3, Bit#(1)) flags = takeAt(48, dataVec);
  Vector#(13, Bit#(1)) fragOffset = takeAt(51, dataVec);
  Vector#(8, Bit#(1)) ttl = takeAt(64, dataVec);
  Vector#(8, Bit#(1)) protocol = takeAt(72, dataVec);
  Vector#(16, Bit#(1)) hdrChecksum = takeAt(80, dataVec);
  Vector#(32, Bit#(1)) srcAddr = takeAt(96, dataVec);
  Vector#(32, Bit#(1)) dstAddr = takeAt(128, dataVec);
  Ipv4T hdr = defaultValue;
  hdr.version = pack(version);
  hdr.ihl = pack(ihl);
  hdr.diffserv = pack(diffserv);
  hdr.totalLen = pack(totalLen);
  hdr.identification = pack(identification);
  hdr.flags = pack(flags);
  hdr.fragOffset = pack(fragOffset);
  hdr.ttl = pack(ttl);
  hdr.protocol = pack(protocol);
  hdr.hdrChecksum = pack(hdrChecksum);
  hdr.srcAddr = pack(srcAddr);
  hdr.dstAddr = pack(dstAddr);
  return hdr;
endfunction

typedef struct {
  Bit#(48) dstAddr;
  Bit#(48) srcAddr;
  Bit#(16) etherType;
} EthernetT deriving (Bits, Eq);

instance DefaultValue#(EthernetT);
  defaultValue = unpack(0);
endinstance
instance DefaultMask#(EthernetT);
  defaultMask = unpack(maxBound);
endinstance

instance FShow#(EthernetT);
  function Fmt fshow(EthernetT p);
    return $format("EthernetT: dstAddr=%h, srcAddr=%h, etherType=%h", p.dstAddr, p.srcAddr, p.etherType);
  endfunction
endinstance

function EthernetT extract_ethernet_t(Bit#(112) data);
  Vector#(112, Bit#(1)) dataVec = unpack(data);
  Vector#(48, Bit#(1)) dstAddr = takeAt(0, dataVec);
  Vector#(48, Bit#(1)) srcAddr = takeAt(48, dataVec);
  Vector#(16, Bit#(1)) etherType = takeAt(96, dataVec);
  EthernetT hdr = defaultValue;
  hdr.dstAddr = pack(dstAddr);
  hdr.srcAddr = pack(srcAddr);
  hdr.etherType = pack(etherType);
  return hdr;
endfunction

typedef struct {
  Bit#(32) dstAddr;
  Bit#(16) etherType;
} MetaT deriving (Bits, Eq);

instance DefaultValue#(MetaT);
  defaultValue = unpack(0);
endinstance
instance DefaultMask#(MetaT);
  defaultMask = unpack(maxBound);
endinstance

instance FShow#(MetaT);
  function Fmt fshow(MetaT p);
    return $format("MetaT: dstAddr=%h, etherType=%h", p.dstAddr, p.etherType);
  endfunction
endinstance

function MetaT extract_meta_t(Bit#(48) data);
  Vector#(48, Bit#(1)) dataVec = unpack(data);
  Vector#(32, Bit#(1)) dstAddr = takeAt(0, dataVec);
  Vector#(16, Bit#(1)) etherType = takeAt(32, dataVec);
  MetaT hdr = defaultValue;
  hdr.dstAddr = pack(dstAddr);
  hdr.etherType = pack(etherType);
  return hdr;
endfunction

interface Routing;
  interface Client#(MetadataRequest, MetadataResponse) next;
endinterface

module mkRouting#(Client#(MetadataRequest, MetadataResponse) md)(Routing);
  let verbose = True;

  FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
  FIFO#(MetadataResponse) inRespFifo <- mkFIFO;

  MatchTable#(512, SizeOf#(RoutingReqT), SizeOf#(RoutingRespT)) matchTable <- mkMatchTable;

  rule handleRequest;
    let v <- md.request.get;
    case (v) matches
      default: begin
         // Lookup
      end
    endcase
  endrule

  rule handleResponse;
    // response action
    // build tagged response: forward, drop
  endrule

  interface next = (interface Client#(MetadataRequest, MetadataResponse);
    interface request = toGet(outReqFifo);
    interface response = toPut(inRespFifo);
  endinterface);
endmodule


interface BasicBlockForward;
   interface BBServer prev_control_state;
endinterface
module mkBasicBlockForward(BasicBlockForward);
   FIFO#(BBRequest) bb_forward_request_fifo <- mkSizedFIFO(1);
   FIFO#(BBResponse) bb_forward_response_fifo <- mkSizedFIFO(1);
   FIFO#(PacketInstance) curr_packet_fifo <- mkSizedFIFO(1);

   rule bb_handle_forward;
      let req <- toGet(bb_forward_request_fifo).get;
      case (req) matches
         tagged BBForwardRequest {pkt: .pkt, egress_port: .egress_port}: begin
            BBResponse resp;
            resp = tagged BBForwardResponse {pkt: pkt, egress_port: egress_port};
            bb_forward_response_fifo.enq(resp);
            $display("(%0d) handle forward", $time);
         end
      endcase
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_forward_request_fifo);
      interface response = toGet(bb_forward_response_fifo);
   endinterface);
endmodule

interface BasicBlockNop;
   interface BBServer prev_control_state;
endinterface
module mkBasicBlockNop(BasicBlockNop);
   FIFO#(BBRequest) bb_nop_request_fifo <- mkSizedFIFO(1);
   FIFO#(BBResponse) bb_nop_response_fifo <- mkSizedFIFO(1);

   rule bb_handle_nop;

   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_nop_request_fifo);
      interface response = toGet(bb_nop_response_fifo);
   endinterface);
endmodule

(* synthesize *)
module mkMatchTable_256_routingTable(MatchTable#(256, SizeOf#(RoutingReqT), SizeOf#(RoutingRespT)));
   MatchTable#(256, SizeOf#(RoutingReqT), SizeOf#(RoutingRespT)) ifc <- mkMatchTable();
   return ifc;
endmodule

interface RoutingTable;
   interface BBClient next_control_state_0;
   interface BBClient next_control_state_1;
   method Action add_entry(Bit#(32) dstAddr, RouteActionT action_, Bit#(9) port_);
endinterface
module mkRoutingTable#(MetadataClient md)(RoutingTable);
   let verbose = True;

   MatchTable#(256, SizeOf#(RoutingReqT), SizeOf#(RoutingRespT)) matchTable <- mkMatchTable_256_routingTable();
   Vector#(2, FIFOF#(BBRequest)) bbReqFifo <- replicateM(mkFIFOF());
   Vector#(2, FIFOF#(BBResponse)) bbRespFifo <- replicateM(mkFIFOF());
   Vector#(2, Bool) readyBits = map(fifoNotEmpty, bbRespFifo);
   Bool interruptStatus = False;
   Bit#(16) readyChannel = -1;

   for (Integer i = 1; i>=0; i=i-1) begin
      if (readyBits[i]) begin
         interruptStatus = True;
         readyChannel = fromInteger(i);
      end
   end

   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;
   FIFO#(MetadataT) bbMetadataFifo <- mkFIFO;

   rule routing_request;
      let v <- md.request.get;
      case (v) matches
         tagged RoutingTableRequest {pkt: .pkt, meta: .meta}: begin
            RoutingReqT req = RoutingReqT {padding: 0, dstAddr: fromMaybe(?, meta.dstAddr)};
            matchTable.lookupPort.request.put(pack(req));
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
            $display("(%0d) forward routing request", $time);
         end
      endcase
   endrule

   rule routing_response;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;

      if (v matches tagged Valid .data) begin
         RoutingRespT resp = unpack(data);
         case (resp.p4_action) matches
            NOP: begin
               BBRequest req;
               req = tagged BBNopRequest {pkt: pkt};
               bbReqFifo[0].enq(req);
            end
            FORWARD: begin
               Bit#(9) egress_port = resp.action_1_arg0;
               BBRequest req;
               req = tagged BBForwardRequest {pkt: pkt, egress_port: egress_port};
               bbReqFifo[1].enq(req);
               $display("(%0d) routing response", $time);
            end
         endcase
         bbMetadataFifo.enq(meta);
      end
      else begin
         $display("(%0d) missed, drop packet");
      end
   endrule

   rule bb_handle_resp if (interruptStatus);
      let v <- toGet(bbRespFifo[readyChannel]).get;
      let meta <- toGet(bbMetadataFifo).get;
      case (v) matches
         tagged BBNopResponse {pkt: .pkt}: begin
            MetadataResponse resp = tagged RoutingTableResponse {pkt: pkt, meta: meta};
            md.response.put(resp);
         end
         tagged BBForwardResponse {pkt: .pkt, egress_port: .egress_port}: begin
            meta.egress_port = tagged Valid egress_port;
            MetadataResponse resp = tagged RoutingTableResponse {pkt: pkt, meta: meta};
            md.response.put(resp);
            $display("(%0d) forward response", $time);
         end
      endcase
   endrule

   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(bbReqFifo[0]);
      interface response = toPut(bbRespFifo[0]);
   endinterface);
   interface next_control_state_1 = (interface BBClient;
      interface request = toGet(bbReqFifo[1]);
      interface response = toPut(bbRespFifo[1]);
   endinterface);
   method Action add_entry(Bit#(32) dstAddr, RouteActionT action_, Bit#(9) port_);
      RoutingReqT req = RoutingReqT {dstAddr: dstAddr, padding: 0};
      RoutingRespT resp = RoutingRespT {p4_action: action_, action_1_arg0: port_};
      if (verbose) $display("(%0d) routing table resp=%h", $time, pack(resp));
      matchTable.add_entry.put(tuple2(pack(req), pack(resp)));
   endmethod
endmodule

interface Ingress0;
   interface PipeOut#(MetadataRequest) eventPktSend;
   method Action routingTable_add_entry(Bit#(32) dstAddr, RouteActionT act, Bit#(9) port_);
endinterface

module mkIngress0#(Vector#(numClients, MetadataClient) mdc)(Ingress0);
  let verbose = True;
  FIFOF#(MetadataRequest) currPacketFifo <- mkFIFOF;
  FIFO#(MetadataRequest) defaultReqFifo <- mkFIFO;
  FIFO#(MetadataResponse) defaultRespFifo <- mkFIFO;

  FIFO#(MetadataRequest) routingReqFifo <- mkFIFO;
  FIFO#(MetadataResponse) routingRespFifo <- mkFIFO;

  Vector#(numClients, MetadataServer) mds = newVector;
  for (Integer i=0; i<valueOf(numClients); i=i+1) begin
    mds[i] = (interface MetadataServer;
      interface Put request = toPut(defaultReqFifo);
      interface Get response = toGet(defaultRespFifo);
    endinterface);
  end
  mkConnection(mdc, mds);

  function MetadataClient toMetadataClient(FIFO#(MetadataRequest) reqFifo,
                                           FIFO#(MetadataResponse) respFifo);
    MetadataClient ret_ifc;
    ret_ifc = (interface MetadataClient;
      interface Get request = toGet(reqFifo);
      interface Put response = toPut(respFifo);
    endinterface);
    return ret_ifc;
  endfunction

  RoutingTable routingTable <- mkRoutingTable(toGPClient(routingReqFifo, routingRespFifo));

  // BasicBlock
  BasicBlockForward bb_fwd <- mkBasicBlockForward();
  BasicBlockNop bb_drop <- mkBasicBlockNop();

  // Connect Table width BasicBlock
  mkConnection(routingTable.next_control_state_0, bb_drop.prev_control_state);
  mkConnection(routingTable.next_control_state_1, bb_fwd.prev_control_state);

  rule default_next_control_state if (defaultReqFifo.first matches tagged DefaultRequest {pkt: .pkt, meta: .meta});
    defaultReqFifo.deq;
    MetadataRequest req = tagged RoutingTableRequest {pkt: pkt, meta: meta};
    $display("(%0d) default request", $time);
    routingReqFifo.enq(req);
  endrule

  rule routing_tbl_next_control_state if (routingRespFifo.first matches tagged RoutingTableResponse {pkt: .pkt, meta: .meta});
    routingRespFifo.deq;
    if (meta.routingtable$route matches tagged Valid .route) begin
      case (route) matches
         FORWARD: begin
           MetadataRequest req = tagged ForwardQueueRequest {pkt: pkt, meta: meta};
           currPacketFifo.enq(req);
         end
         NOP: begin
           MetadataRequest req = tagged ForwardQueueRequest {pkt: pkt, meta: meta};
           currPacketFifo.enq(req);
         end
      endcase
    end
  endrule

  interface eventPktSend = toPipeOut(currPacketFifo);
  method routingTable_add_entry = routingTable.add_entry;
endmodule

typedef enum {
   StateParseStart,
   StateParseEthernet,
   StateParseIpv4
} ParserState deriving (Bits, Eq);
module mkStateParseStart#(Reg#(ParserState) state, FIFOF#(EtherData) datain, Wire#(Bool) start_fsm)(Empty);
  rule load_packet if (state == StateParseStart);
    let v = datain.first;
    if (v.sop) begin
      state <= StateParseEthernet;
      start_fsm <= True;
    end
    else begin
      datain.deq;
      start_fsm <= False;
    end
  endrule
endmodule

interface ParseEthernet;

  interface Get#(Bit#(16)) parse_ipv4;
  interface Get#(Bit#(16)) parsedOut_ethernet_etherType;
  method Action start;
  method Action stop;
endinterface
module mkStateParseEthernet#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseEthernet);
  let verbose = False;
  FIFO#(Bit#(16)) unparsed_parse_ipv4_fifo <- mkFIFO;
  FIFOF#(Bit#(16)) parsed_etherType_fifo <- mkFIFOF;
  Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
  Vector#(4, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
  PulseWire start_wire <- mkPulseWire();
  PulseWire stop_wire <- mkPulseWire();
  (* fire_when_enabled *)
  rule arbitrate_outgoing_state if (state == StateParseEthernet);
    Vector#(4, Bool) next_state_valid = replicate(False);
    Bool stateSet = False;
    for (Integer port=0; port<4; port=port+1) begin
      next_state_valid[port] = isValid(next_state_wire[port]);
      if (!stateSet && next_state_valid[port]) begin
        stateSet = True;
        ParserState next_state = fromMaybe(?, next_state_wire[port]);
        state <= next_state;
      end
    end
  endrule

  function ParserState compute_next_state(Bit#(16) v);
    ParserState nextState = StateParseStart;
    case (byteSwap(v)) matches
      'h800: begin
        nextState = StateParseIpv4;
      end
      default: begin
        nextState = StateParseStart;
      end
    endcase
    return nextState;
  endfunction

  rule load_packet if (state == StateParseEthernet);
    let data_current <- toGet(datain).get;
    packet_in_wire <= data_current.data;
  endrule

  Stmt parse_ethernet =
  seq
  action
    let data_this_cycle = packet_in_wire;
    Vector#(128, Bit#(1)) dataVec = unpack(data_this_cycle);
    Vector#(16, Bit#(1)) unparsed = takeAt(112, dataVec);
    let ethernet_t = extract_ethernet_t(pack(takeAt(0, dataVec)));
    let nextState = compute_next_state(ethernet_t.etherType);
    if (verbose) $display("Goto state ", nextState);
    if (nextState == StateParseIpv4) begin
      unparsed_parse_ipv4_fifo.enq(pack(unparsed));
    end
    parsed_etherType_fifo.enq(ethernet_t.etherType);
    next_state_wire[0] <= tagged Valid nextState;
  endaction
  endseq;
  FSM fsm_parse_ethernet <- mkFSM(parse_ethernet);
  rule start_fsm if (start_wire);
    fsm_parse_ethernet.start;
  endrule
  rule stop_fsm if (stop_wire);
    fsm_parse_ethernet.abort;
  endrule

  method start = start_wire.send;
  method stop = stop_wire.send;
  interface parse_ipv4 = toGet(unparsed_parse_ipv4_fifo);
  interface parsedOut_ethernet_etherType = toGet(parsed_etherType_fifo);
endmodule

interface ParseIpv4;
  interface Put#(Bit#(16)) parse_ethernet;
  interface Get#(Bit#(8)) parsedOut_ipv4_protocol;
  interface Get#(Bit#(32)) parsedOut_ipv4_dstAddr;
  method Action start;
  method Action stop;
endinterface
module mkStateParseIpv4#(Reg#(ParserState) state, FIFOF#(EtherData) datain, FIFOF#(ParserState) parseStateFifo)(ParseIpv4);
  let verbose = False;
  FIFOF#(Bit#(16)) unparsed_parse_ethernet_fifo <- mkBypassFIFOF;

  FIFOF#(Bit#(8)) parsed_ipv4_protocol_fifo <- mkFIFOF;
  FIFOF#(Bit#(32)) parsed_ipv4_dstAddr_fifo <- mkFIFOF;
  FIFOF#(Bit#(144)) internal_fifo_144 <- mkSizedFIFOF(1);

  Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
  Vector#(4, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
  PulseWire start_wire <- mkPulseWire();
  PulseWire stop_wire <- mkPulseWire();
  (* fire_when_enabled *)
  rule arbitrate_outgoing_state if (state == StateParseIpv4);
    Vector#(4, Bool) next_state_valid = replicate(False);
    Bool stateSet = False;
    for (Integer port=0; port<4; port=port+1) begin
      next_state_valid[port] = isValid(next_state_wire[port]);
      if (!stateSet && next_state_valid[port]) begin
        stateSet = True;
        ParserState next_state = fromMaybe(?, next_state_wire[port]);
        state <= next_state;
      end
    end
  endrule

  rule load_packet if (state == StateParseIpv4);
    let data_current <- toGet(datain).get;
    packet_in_wire <= data_current.data;
  endrule
  Stmt parse_ipv4 =
  seq
  action
    let data_this_cycle = packet_in_wire;
    let data_last_cycle <- toGet(unparsed_parse_ethernet_fifo).get;
    Bit#(144) data = {data_this_cycle, data_last_cycle};
    internal_fifo_144.enq(data);
  endaction
  action
    let data_this_cycle = packet_in_wire;
    let data_last_cycle <- toGet(internal_fifo_144).get;
    Bit#(272) data = {data_this_cycle, data_last_cycle};
    Vector#(272, Bit#(1)) dataVec = unpack(data);
    let ipv4_t = extract_ipv4_t(pack(takeAt(0, dataVec)));
    parseStateFifo.enq(StateParseIpv4);
    parsed_ipv4_protocol_fifo.enq(ipv4_t.protocol);
    parsed_ipv4_dstAddr_fifo.enq(ipv4_t.dstAddr);
    next_state_wire[0] <= tagged Valid StateParseStart;
  endaction
  endseq;
  FSM fsm_parse_ipv4 <- mkFSM(parse_ipv4);
  rule start_fsm if (start_wire);
    fsm_parse_ipv4.start;
  endrule
  rule stop_fsm if (stop_wire);
    fsm_parse_ipv4.abort;
  endrule
  method start = start_wire.send;
  method stop = stop_wire.send;
  interface parse_ethernet = toPut(unparsed_parse_ethernet_fifo);
  interface parsedOut_ipv4_protocol = toGet(parsed_ipv4_protocol_fifo);
  interface parsedOut_ipv4_dstAddr = toGet(parsed_ipv4_dstAddr_fifo);
endmodule

interface Parser;
  interface Put#(EtherData) frameIn;
  interface Get#(MetadataT) meta;
  method ParserPerfRec read_perf_info;
endinterface
typedef 4 PortMax;
(* synthesize *)
module mkParser(Parser);
  Reg#(ParserState) curr_state <- mkReg(StateParseStart);
  Reg#(Bool) started <- mkReg(False);
  FIFOF#(EtherData) data_in_fifo <- mkFIFOF;
  Wire#(Bool) start_fsm <- mkDWire(False);

  Vector#(PortMax, FIFOF#(ParserState)) parse_state_in_fifo <- replicateM(mkGFIFOF(False, True)); // ungarded deq
  FIFOF#(ParserState) parse_state_out_fifo <- mkFIFOF;
  FIFOF#(MetadataT) metadata_out_fifo <- mkFIFOF;

  (* fire_when_enabled *)
  rule arbitrate_parse_state;
    Bool sentOne = False;
    for (Integer port=0; port<valueOf(PortMax); port=port+1) begin
      if (!sentOne && parse_state_in_fifo[port].notEmpty()) begin
        ParserState state <- toGet(parse_state_in_fifo[port]).get;
        sentOne = True;
        parse_state_out_fifo.enq(state);
      end
    end
  endrule

  Empty init_state <- mkStateParseStart(curr_state, data_in_fifo, start_fsm);
  ParseIpv4 parse_ipv4 <- mkStateParseIpv4(curr_state, data_in_fifo, parse_state_in_fifo[0]);
  ParseEthernet parse_ethernet <- mkStateParseEthernet(curr_state, data_in_fifo);
  mkConnection(parse_ipv4.parse_ethernet, parse_ethernet.parse_ipv4);
  rule start if (start_fsm);
    if (!started) begin
      parse_ipv4.start;
      parse_ethernet.start;
      started <= True;
    end
  endrule

  rule stop if (!start_fsm && curr_state == StateParseStart);
    if (started) begin
      parse_ipv4.stop;
      parse_ethernet.stop;
      started <= False;
    end
  endrule

  // handle ipv4 packet
  rule handle_ipv4_packet if (parse_state_out_fifo.first == StateParseIpv4);
    parse_state_out_fifo.deq;
    let protocol <- toGet(parse_ipv4.parsedOut_ipv4_protocol).get;
    let etherType <- toGet(parse_ethernet.parsedOut_ethernet_etherType).get;
    let dstAddr <- toGet(parse_ipv4.parsedOut_ipv4_dstAddr).get;
    $display("(%0d) handle ipv4", $time);
    MetadataT meta = defaultValue;
    meta.protocol = tagged Valid protocol;
    meta.etherType = tagged Valid etherType;
    meta.dstAddr = tagged Valid dstAddr;
    meta.valid_ipv4 = tagged Valid True;
    meta.valid_ethernet = tagged Valid True;
    metadata_out_fifo.enq(meta);
  endrule

  interface frameIn = toPut(data_in_fifo);
  interface meta = toGet(metadata_out_fifo);
endmodule

typedef enum {
  StateDeparseIdle,
  StateDeparseEthernet,
  StateDeparseIpv4
} DeparserState deriving (Bits, Eq, FShow);

function Tuple2#(EthernetT, EthernetT) toEthernet(MetadataT meta);
   EthernetT data = defaultValue;
   EthernetT mask = defaultMask;
   data.etherType = fromMaybe(?, meta.etherType);
   mask.etherType = 0;
   return tuple2(data, mask);
endfunction

function Tuple2#(Ipv4T, Ipv4T) toIpv4(MetadataT meta);
   Ipv4T ipv4 = defaultValue;
   Ipv4T mask = defaultMask;
   ipv4.protocol = fromMaybe(?, meta.protocol);
   mask.protocol = 0;
   return tuple2(ipv4, mask);
endfunction

module mkStateDeparseIdle#(Reg#(DeparserState) state, FIFOF#(EtherData) datain, FIFOF#(EtherData) dataout, Wire#(Bool) start_fsm)(Empty);

   rule load_packet if (state == StateDeparseIdle);
      let v = datain.first;
      if (v.sop) begin
         state <= StateDeparseEthernet;
         start_fsm <= True;
         $display("(%0d) Deparse Ethernet Start", $time, fshow(v));
      end
      else begin
         datain.deq;
         dataout.enq(v);
         $display("(%0d) payload ", $time, fshow(v));
         start_fsm <= False;
      end
   endrule
endmodule

interface DeparseEthernet;
  interface Get#(EtherData) deparse_ipv4;
  method Action start;
  method Action stop;
endinterface
module mkStateDeparseEthernet#(Reg#(DeparserState) state, FIFOF#(EtherData) datain, FIFOF#(EtherData) dataout, FIFOF#(EthernetT) meta_fifo, FIFOF#(EthernetT) mask_fifo)(DeparseEthernet);
  let verbose = True;
  Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);

  FIFO#(EtherData) deparse_ipv4_fifo <- mkFIFO;
  PulseWire start_wire <- mkPulseWire;
  PulseWire stop_wire <- mkPulseWire;

  function DeparserState compute_next_state(Bit#(16) v);
    DeparserState nextState = StateDeparseIdle;
    case (byteSwap(v)) matches
      'h800: begin
        nextState = StateDeparseIpv4;
      end
      default: begin
        nextState = StateDeparseIdle;
      end
    endcase
    return nextState;
  endfunction

  rule load_packet if (state == StateDeparseEthernet);
    let data_current <- toGet(datain).get;
    packet_in_wire <= data_current;
    $display("(%0d) Ether: ", $time, fshow(data_current));
  endrule
  Stmt deparse_ethernet =
  seq
  action
    let data_this_cycle = packet_in_wire;
    Vector#(16, Bit#(1)) unused = takeAt(112, unpack(data_this_cycle.data));
    Vector#(112, Bit#(1)) data = takeAt(0, unpack(data_this_cycle.data));
    Vector#(112, Bit#(1)) curr_meta = takeAt(0, unpack(byteSwap(pack(meta_fifo.first))));
    Vector#(112, Bit#(1)) curr_mask = takeAt(0, unpack(byteSwap(pack(mask_fifo.first))));
    let masked_data = pack(data) & pack(curr_mask);
    let curr_data = masked_data | pack(curr_meta);
    EthernetT ethernet_t = unpack(pack(masked_data));
    data_this_cycle.data = {pack(unused), pack(curr_data)};
    let nextState = compute_next_state(meta_fifo.first.etherType);
    if (verbose) $display("(%0d) etherType", $time, meta_fifo.first.etherType);
    if (verbose) $display("(%0d) Goto state ", $time, nextState);
    state <= nextState;
    $display("(%0d) deparse ethernet ", $time, fshow(nextState), fshow(data_this_cycle));
    if (nextState == StateDeparseIpv4) begin
      deparse_ipv4_fifo.enq(data_this_cycle);
    end
    meta_fifo.deq;
    mask_fifo.deq;
  endaction
  endseq;

  FSM fsm_deparse_ethernet <- mkFSM(deparse_ethernet);
  rule start_fsm if (start_wire);
    fsm_deparse_ethernet.start;
  endrule
  rule stop_fsm if (stop_wire);
    fsm_deparse_ethernet.abort;
  endrule
  method Action start();
     start_wire.send();
  endmethod
  method Action stop();
     stop_wire.send();
  endmethod
  interface deparse_ipv4 = toGet(deparse_ipv4_fifo);
endmodule

interface DeparseIpv4;
  interface Put#(EtherData) deparse_ethernet;
  method Action start;
  method Action stop;
endinterface
module mkStateDeparseIpv4#(Reg#(DeparserState) state, FIFOF#(EtherData) datain, FIFOF#(EtherData) dataout, FIFOF#(Ipv4T) meta_fifo, FIFOF#(Ipv4T) mask_fifo)(DeparseIpv4);
  let verbose = True;
  Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);
  FIFOF#(EtherData) deparse_ethernet_fifo <- mkBypassFIFOF;
  PulseWire start_wire <- mkPulseWire;
  PulseWire stop_wire <- mkPulseWire;

  rule load_packet if (state == StateDeparseIpv4 && !deparse_ethernet_fifo.notEmpty());
    let data_current <- toGet(datain).get;
    packet_in_wire <= data_current;
    $display("(%0d) IPv4: ", $time, fshow(data_current));
  endrule
  Stmt deparse_ipv4 =
  seq
  action
    let data_this_cycle <- toGet(deparse_ethernet_fifo).get;
    Vector#(112, Bit#(1)) unused = takeAt(0, unpack(data_this_cycle.data));
    Vector#(16, Bit#(1)) data = takeAt(112, unpack(data_this_cycle.data));
    Vector#(16, Bit#(1)) curr_meta = takeAt(0, unpack(byteSwap(pack(meta_fifo.first))));
    Vector#(16, Bit#(1)) curr_mask = takeAt(0, unpack(byteSwap(pack(mask_fifo.first))));
    let masked_data = pack(data) & pack(curr_mask);
    let curr_data = masked_data | pack(curr_meta);
    $display("(%0d) IPv4: [1] ", $time, fshow(data_this_cycle), " meta=%h, mask=%h", curr_mask, curr_meta);
    data_this_cycle.data = {pack(curr_data), pack(unused)};
    dataout.enq(data_this_cycle);
  endaction
  action
    let data_this_cycle = packet_in_wire;
    Vector#(128, Bit#(1)) data = takeAt(0, unpack(data_this_cycle.data));
    Vector#(128, Bit#(1)) curr_meta = takeAt(16, unpack(byteSwap(pack(meta_fifo.first))));
    Vector#(128, Bit#(1)) curr_mask = takeAt(16, unpack(byteSwap(pack(mask_fifo.first))));
    let masked_data = pack(data) & pack(curr_mask);
    let curr_data = masked_data | pack(curr_meta);
    data_this_cycle.data = {pack(curr_data)};
    dataout.enq(data_this_cycle);
    $display("(%0d) IPv4: [2] ", $time, fshow(data_this_cycle));
  endaction
  action
    let data_this_cycle = packet_in_wire;
    Vector#(112, Bit#(1)) unused = takeAt(16, unpack(data_this_cycle.data));
    Vector#(16, Bit#(1)) data = takeAt(0, unpack(data_this_cycle.data));
    Vector#(16, Bit#(1)) curr_meta = takeAt(144, unpack(byteSwap(pack(meta_fifo.first))));
    Vector#(16, Bit#(1)) curr_mask = takeAt(144, unpack(byteSwap(pack(mask_fifo.first))));
    let masked_data = pack(data) & pack(curr_mask);
    let curr_data = masked_data | pack(curr_meta);
    //Ipv4T ipv4_t = unpack(pack(masked_data));
    data_this_cycle.data = {pack(unused), pack(curr_data)};
    $display("(%0d) compute_next_state protocol", $time, fshow(meta_fifo.first.protocol));
    dataout.enq(data_this_cycle);
    state <= StateDeparseIdle;
    meta_fifo.deq;
    mask_fifo.deq;
  endaction
  endseq;

  FSM fsm_deparse_ipv4 <- mkFSM(deparse_ipv4);
  rule start_fsm if (start_wire);
    fsm_deparse_ipv4.start;
  endrule
  rule stop_fsm if (stop_wire);
    fsm_deparse_ipv4.abort;
  endrule
  method Action start();
     start_wire.send();
  endmethod
  method Action stop();
     stop_wire.send();
  endmethod
  interface deparse_ethernet = toPut(deparse_ethernet_fifo);
endmodule

interface Deparser;
  interface PipeIn#(MetadataT) metadata;
  interface PktWriteServer writeServer;
  interface PktWriteClient writeClient;
  method DeparserPerfRec read_perf_info;
endinterface
(* synthesize *)
module mkDeparser(Deparser);
  let verbose = False;
  FIFOF#(EtherData) data_in_fifo <- mkSizedFIFOF(4);
  FIFOF#(EtherData) data_out_fifo <- mkFIFOF;
  FIFOF#(MetadataT) metadata_in_fifo <- mkFIFOF;
  Reg#(Bool) started <- mkReg(False);
  Wire#(Bool) start_fsm <- mkDWire(False);
  Reg#(DeparserState) curr_state <- mkReg(StateDeparseIdle);

  Vector#(PortMax, FIFOF#(DeparserState)) deparse_state_in_fifo <- replicateM(mkGFIFOF(False, True));
  FIFOF#(DeparserState) deparse_state_out_fifo <- mkFIFOF;
  FIFOF#(EthernetT) deparse_ethernet_meta_fifo <- mkFIFOF;
  FIFOF#(Ipv4T) deparse_ipv4_meta_fifo <- mkFIFOF;
  FIFOF#(EthernetT) deparse_ethernet_mask_fifo <- mkFIFOF;
  FIFOF#(Ipv4T) deparse_ipv4_mask_fifo <- mkFIFOF;

  Reg#(Bit#(32)) clk_cnt <- mkReg(0);
  Reg#(Bit#(32)) deparser_start_time <- mkReg(0);
  Reg#(Bit#(32)) deparser_end_time <- mkReg(0);
  rule clockrule;
    clk_cnt <= clk_cnt + 1;
  endrule

  (* fire_when_enabled *)
  rule arbitrate_deparse_state;
    Bool sentOne = False;
    for (Integer port = 0; port < valueOf(PortMax); port = port+1) begin
      if (!sentOne && deparse_state_in_fifo[port].notEmpty()) begin
        DeparserState state <- toGet(deparse_state_in_fifo[port]).get();
        sentOne = True;
        $display("(%0d) xxx arbitrate %h", $time, port);
        deparse_state_out_fifo.enq(state);
      end
    end
  endrule

  rule get_metadata;
     let v <- toGet(metadata_in_fifo).get;
     let ethernet = toEthernet(v);
     match {.data, .mask} = ethernet;
     deparse_ethernet_meta_fifo.enq(data);
     deparse_ethernet_mask_fifo.enq(mask);

     let ipv4 = toIpv4(v);
     match {.ipv4_data, .ipv4_mask} = ipv4;
     if (verbose) $display("(%0d) ipv4 meta", $time, fshow(ipv4));
     deparse_ipv4_meta_fifo.enq(ipv4_data);
     deparse_ipv4_mask_fifo.enq(ipv4_mask);
  endrule

  Empty init_state <- mkStateDeparseIdle(curr_state, data_in_fifo, data_out_fifo, start_fsm);
  DeparseEthernet deparse_ethernet <- mkStateDeparseEthernet(curr_state, data_in_fifo, data_out_fifo, deparse_ethernet_meta_fifo, deparse_ethernet_mask_fifo);
  DeparseIpv4 deparse_ipv4 <- mkStateDeparseIpv4(curr_state, data_in_fifo, data_out_fifo, deparse_ipv4_meta_fifo, deparse_ipv4_mask_fifo);
  mkConnection(deparse_ethernet.deparse_ipv4,deparse_ipv4.deparse_ethernet);

  rule start if (start_fsm);
    if (!started) begin
      $display("(%0d) start deparser", $time);
      deparse_ethernet.start;
      deparse_ipv4.start;
      started <= True;
      deparser_start_time <= clk_cnt;
    end
  endrule
  rule stop if (!start_fsm && curr_state == StateDeparseIdle);
    if (started) begin
      $display("(%0d) stop deparser", $time);
      deparse_ethernet.stop;
      deparse_ipv4.stop;
      started <= False;
      deparser_end_time <= clk_cnt;
    end
  endrule
  interface PktWriteServer writeServer;
    interface writeData = toPut(data_in_fifo);
  endinterface
  interface PktWriteClient writeClient;
    interface writeData = toGet(data_out_fifo);
  endinterface
  interface metadata = toPipeIn(metadata_in_fifo);
  method DeparserPerfRec read_perf_info;
    return DeparserPerfRec {
      deparser_start_time: deparser_start_time,
      deparser_end_time: deparser_end_time
    };
  endmethod
endmodule