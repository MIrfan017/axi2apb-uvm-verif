// AXI monitor: samples through monitor_cb on posedge, publishes one item per
// completed transaction.
class axi_monitor extends uvm_monitor;

  `uvm_component_utils(axi_monitor)

  axi_vif_t                          vif;
  uvm_analysis_port #(axi_seq_item)  ap;

  protected axi_seq_item aw_q[$];
  protected axi_seq_item w_q[$];
  protected axi_seq_item ar_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(axi_vif_t)::get(this, "", "axi_vif", vif))
      `uvm_fatal("NOVIF", "axi_monitor: axi_vif not found in config_db (set it in tb_top)")
  endfunction

  task run_phase(uvm_phase phase);
    axi_seq_item t;
    axi_seq_item aw_t;
    axi_seq_item w_t;
    axi_seq_item ar_t;
    forever begin
      @(vif.monitor_cb);
      if (vif.rst_n !== 1'b1) begin
        aw_q.delete();
        w_q.delete();
        ar_q.delete();
      end else begin
        // ---- AW handshake
        if (vif.monitor_cb.aw_valid === 1'b1 && vif.monitor_cb.aw_ready === 1'b1) begin
          t = axi_seq_item::type_id::create("aw_t");
          t.write = 1'b1;
          t.addr  = vif.monitor_cb.aw_addr;
          t.id    = vif.monitor_cb.aw_id;
          t.user  = vif.monitor_cb.aw_user;
          t.len   = vif.monitor_cb.aw_len;
          t.size  = vif.monitor_cb.aw_size;
          t.burst = vif.monitor_cb.aw_burst;
          aw_q.push_back(t);
        end
        // ---- W handshake
        if (vif.monitor_cb.w_valid === 1'b1 && vif.monitor_cb.w_ready === 1'b1) begin
          t = axi_seq_item::type_id::create("w_t");
          t.data = vif.monitor_cb.w_data;
          t.strb = vif.monitor_cb.w_strb;
          t.last = vif.monitor_cb.w_last;
          w_q.push_back(t);
        end
        // ---- B handshake -> write complete
        if (vif.monitor_cb.b_valid === 1'b1 && vif.monitor_cb.b_ready === 1'b1) begin
          if (aw_q.size() == 0 || w_q.size() == 0) begin
            `uvm_error("AXI_MON", "B handshake without matching AW/W")
          end else begin
            aw_t = aw_q.pop_front();
            w_t  = w_q.pop_front();
            aw_t.data      = w_t.data;
            aw_t.strb      = w_t.strb;
            aw_t.resp      = vif.monitor_cb.b_resp;
            aw_t.resp_id   = vif.monitor_cb.b_id;
            aw_t.resp_user = vif.monitor_cb.b_user;
            `uvm_info("AXI_MON", {"complete: ", aw_t.convert2string()}, UVM_HIGH)
            ap.write(aw_t);
          end
        end
        // ---- AR handshake
        if (vif.monitor_cb.ar_valid === 1'b1 && vif.monitor_cb.ar_ready === 1'b1) begin
          t = axi_seq_item::type_id::create("ar_t");
          t.write = 1'b0;
          t.addr  = vif.monitor_cb.ar_addr;
          t.id    = vif.monitor_cb.ar_id;
          t.user  = vif.monitor_cb.ar_user;
          t.len   = vif.monitor_cb.ar_len;
          t.size  = vif.monitor_cb.ar_size;
          t.burst = vif.monitor_cb.ar_burst;
          ar_q.push_back(t);
        end
        // ---- R handshake -> read complete
        if (vif.monitor_cb.r_valid === 1'b1 && vif.monitor_cb.r_ready === 1'b1) begin
          if (ar_q.size() == 0) begin
            `uvm_error("AXI_MON", "R handshake without matching AR")
          end else begin
            ar_t = ar_q.pop_front();
            ar_t.data      = vif.monitor_cb.r_data;
            ar_t.resp      = vif.monitor_cb.r_resp;
            ar_t.resp_id   = vif.monitor_cb.r_id;
            ar_t.resp_user = vif.monitor_cb.r_user;
            ar_t.last      = vif.monitor_cb.r_last;
            `uvm_info("AXI_MON", {"complete: ", ar_t.convert2string()}, UVM_HIGH)
            ap.write(ar_t);
          end
        end
      end
    end
  endtask

endclass