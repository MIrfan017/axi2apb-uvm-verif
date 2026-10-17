// ============================================================================
// AXI transaction (one single-beat read or write).
// Includes extra AXI fields (prot, cache, qos, region) to improve RTL
// toggle coverage. These fields are ignored by the RTL FSM but pass through
// the buffers, so driving them exercises more RTL lines.
// ============================================================================
class axi_seq_item extends uvm_sequence_item;

  rand bit                         write;       // 1 = write, 0 = read
  rand bit [AXI_ADDR_W-1:0]        addr;
  rand bit [AXI_DATA_W-1:0]        data;        // write: data to send / read: data received
  rand bit [AXI_DATA_W/8-1:0]      strb;
  rand bit [AXI_ID_W-1:0]          id;
  rand bit [AXI_USER_W-1:0]        user;        // AWUSER/ARUSER -> BUSER/RUSER propagation
  rand int unsigned                resp_delay;  // cycles to wait before BREADY / RREADY

  // Extra AXI control fields (for toggle coverage)
  rand bit [2:0]                   prot;
  rand bit [3:0]                   cache;
  rand bit [3:0]                   qos;
  rand bit [3:0]                   region;

  // fixed for this bridge (single beat, 32-bit, INCR)
  bit [7:0]                        len   = 8'd0;
  bit [2:0]                        size  = 3'd2;
  bit [1:0]                        burst = 2'b01;

  // filled in by driver / monitor
  bit [1:0]                        resp;
  bit [AXI_ID_W-1:0]               resp_id;
  bit [AXI_USER_W-1:0]             resp_user;
  bit                              last;

  constraint c_defaults {
    strb       == '1;
    resp_delay inside {[0:8]};
  }

  `uvm_object_utils(axi_seq_item)

  function new(string name = "axi_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h id=0x%0h user=0x%0h resp=%0b resp_id=0x%0h resp_user=0x%0h last=%0b",
                     write ? "WR" : "RD", addr, data, id, user, resp, resp_id, resp_user, last);
  endfunction

endclass