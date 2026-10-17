`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_apb)

class axi_apb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi_apb_scoreboard)

  uvm_analysis_imp_axi #(axi_seq_item, axi_apb_scoreboard) axi_export;
  uvm_analysis_imp_apb #(apb_item,     axi_apb_scoreboard) apb_export;

  protected axi_seq_item axi_q[$];
  protected apb_item     apb_q[$];

  protected bit [AXI_DATA_W-1:0] ref_mem [bit [AXI_ADDR_W-1:0]];

  int unsigned wr_match;
  int unsigned rd_match;
  int unsigned mismatches;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi_export = new("axi_export", this);
    apb_export = new("apb_export", this);
  endfunction

  function void write_axi(axi_seq_item t);
    axi_q.push_back(t);
    try_compare();
  endfunction

  function void write_apb(apb_item t);
    apb_q.push_back(t);
    try_compare();
  endfunction

  // Content-based matching: find the first APB item in the queue with the
  // matching direction+address+data to the AXI item at the head of axi_q.
  // This tolerates arbitrary ordering between the two monitors.
  protected function void try_compare();
    axi_seq_item a;
    apb_item     p;
    int          idx;

    while (axi_q.size() > 0 && apb_q.size() > 0) begin
      a = axi_q[0];
      // find a matching APB item for this AXI item
      idx = -1;
      for (int i = 0; i < apb_q.size(); i++) begin
        if (apb_q[i].write == a.write &&
            apb_q[i].addr  == a.addr  &&
            apb_q[i].data  == a.data) begin
          idx = i;
          break;
        end
      end
      if (idx < 0) begin
        // no matching APB item yet; wait for more arrivals
        return;
      end

      a = axi_q.pop_front();
      p = apb_q[idx];
      apb_q.delete(idx);
      check_pair(a, p);
    end
  endfunction

  protected function void check_pair(axi_seq_item a, apb_item p);
    bit ok = 1'b1;

    if (a.write !== p.write) begin
      `uvm_error("SB", $sformatf("direction mismatch: AXI=%s APB=%s",
                                 a.convert2string(), p.convert2string()))
      mismatches++;
      return;
    end
    if (a.addr !== p.addr) begin
      `uvm_error("SB", $sformatf("address mismatch: AXI=0x%08h APB=0x%08h", a.addr, p.addr))
      ok = 1'b0;
    end
    if (a.data !== p.data) begin
      `uvm_error("SB", $sformatf("data mismatch @0x%08h: AXI=0x%08h APB=0x%08h",
                                 a.addr, a.data, p.data))
      ok = 1'b0;
    end
    if (a.resp !== 2'b00) begin
      `uvm_error("SB", $sformatf("unexpected AXI response %0b @0x%08h", a.resp, a.addr))
      ok = 1'b0;
    end
    if (a.resp_id !== a.id) begin
      `uvm_error("SB", $sformatf("ID mismatch @0x%08h: req=0x%0h resp=0x%0h",
                                 a.addr, a.id, a.resp_id))
      ok = 1'b0;
    end
    if (a.resp_user !== a.user) begin
      `uvm_error("SB", $sformatf("USER mismatch @0x%08h: req=0x%0h resp=0x%0h",
                                 a.addr, a.user, a.resp_user))
      ok = 1'b0;
    end
    if (p.slverr)
      `uvm_info("SB", $sformatf("PSLVERR observed @0x%08h (RTL ignores it)", p.addr), UVM_MEDIUM)

    if (a.write) begin
      ref_mem[a.addr] = a.data;
    end else begin
      if (a.last !== 1'b1) begin
        `uvm_error("SB", $sformatf("RLAST not set @0x%08h", a.addr))
        ok = 1'b0;
      end
      if (ref_mem.exists(a.addr) && (ref_mem[a.addr] !== a.data)) begin
        `uvm_error("SB", $sformatf("read-after-write mismatch @0x%08h: got 0x%08h exp 0x%08h",
                                   a.addr, a.data, ref_mem[a.addr]))
        ok = 1'b0;
      end
    end

    if (ok) begin
      if (a.write) wr_match++; else rd_match++;
      `uvm_info("SB", $sformatf("MATCH  %s", a.convert2string()), UVM_MEDIUM)
    end else begin
      mismatches++;
    end
  endfunction

  function bit is_idle();
    return (axi_q.size() == 0) && (apb_q.size() == 0);
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (axi_q.size() != 0) begin
      foreach (axi_q[i])
        `uvm_error("SB", $sformatf("unmatched AXI: %s", axi_q[i].convert2string()))
    end
    if (apb_q.size() != 0) begin
      foreach (apb_q[i])
        `uvm_error("SB", $sformatf("unmatched APB: %s", apb_q[i].convert2string()))
    end
    if (wr_match + rd_match + mismatches == 0)
      `uvm_error("SB", "scoreboard compared nothing")
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf("writes matched=%0d reads matched=%0d mismatches=%0d",
                              wr_match, rd_match, mismatches), UVM_NONE)
  endfunction

endclass