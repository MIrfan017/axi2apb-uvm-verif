class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  apb_vif_t                         vif;
  uvm_analysis_port #(apb_item)     ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(apb_vif_t)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NOVIF", "apb_monitor: apb_vif not found in config_db (set it in tb_top)")
  endfunction

  task run_phase(uvm_phase phase);
    apb_item     t;
    int unsigned wcnt;
    bit          completed;
    wcnt = 0;
    completed = 1'b0;
    forever begin
      @(vif.monitor_cb);
      if (vif.rst_n !== 1'b1) begin
        wcnt = 0;
        completed = 1'b0;
      end else if (vif.monitor_cb.psel === 1'b1 && vif.monitor_cb.penable === 1'b1) begin
        if (vif.monitor_cb.pready === 1'b1 && !completed) begin
          completed = 1'b1;
          t = apb_item::type_id::create("apb_t");
          t.write       = vif.monitor_cb.pwrite;
          t.addr        = vif.monitor_cb.paddr;
          t.data        = (vif.monitor_cb.pwrite === 1'b1) ? vif.monitor_cb.pwdata : vif.monitor_cb.prdata;
          t.slverr      = vif.monitor_cb.pslverr;
          t.wait_cycles = wcnt;
          `uvm_info("APB_MON", {"transfer: ", t.convert2string()}, UVM_HIGH)
          ap.write(t);
          wcnt = 0;
        end else if (vif.monitor_cb.pready !== 1'b1) begin
          wcnt++;
        end
      end else begin
        wcnt = 0;
        completed = 1'b0;
      end
    end
  endtask

endclass