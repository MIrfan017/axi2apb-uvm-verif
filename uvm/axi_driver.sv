// AXI master driver ? non-blocking drive via master_cb; response payload
// sampled via raw vif to avoid clocking-block input skew on B/R channels.
class axi_driver extends uvm_driver #(axi_seq_item);

  `uvm_component_utils(axi_driver)

  axi_vif_t        vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_vif_t)::get(this, "", "axi_vif", vif))
      `uvm_fatal("NOVIF", "axi_driver: axi_vif not found in config_db (set it in tb_top)")
  endfunction

  task run_phase(uvm_phase phase);
    init_signals();
    wait (vif.rst_n === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.write) drive_write(req);
      else           drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  // ---------------------------------------------------------------- init ----
  task init_signals();
    vif.master_cb.aw_id     <= '0;
    vif.master_cb.aw_addr   <= '0;
    vif.master_cb.aw_len    <= '0;
    vif.master_cb.aw_size   <= '0;
    vif.master_cb.aw_burst  <= '0;
    vif.master_cb.aw_lock   <= 1'b0;
    vif.master_cb.aw_cache  <= '0;
    vif.master_cb.aw_prot   <= '0;
    vif.master_cb.aw_qos    <= '0;
    vif.master_cb.aw_region <= '0;
    vif.master_cb.aw_user   <= '0;
    vif.master_cb.aw_valid  <= 1'b0;

    vif.master_cb.w_data    <= '0;
    vif.master_cb.w_strb    <= '0;
    vif.master_cb.w_last    <= 1'b0;
    vif.master_cb.w_user    <= '0;
    vif.master_cb.w_valid   <= 1'b0;

    vif.master_cb.b_ready   <= 1'b0;

    vif.master_cb.ar_id     <= '0;
    vif.master_cb.ar_addr   <= '0;
    vif.master_cb.ar_len    <= '0;
    vif.master_cb.ar_size   <= '0;
    vif.master_cb.ar_burst  <= '0;
    vif.master_cb.ar_lock   <= 1'b0;
    vif.master_cb.ar_cache  <= '0;
    vif.master_cb.ar_prot   <= '0;
    vif.master_cb.ar_qos    <= '0;
    vif.master_cb.ar_region <= '0;
    vif.master_cb.ar_user   <= '0;
    vif.master_cb.ar_valid  <= 1'b0;

    vif.master_cb.r_ready   <= 1'b0;
  endtask

  // ---------------------------------------------------------------- write ---
  task drive_write(axi_seq_item t);
    // present AW and W together (this RTL requires both valid in IDLE)
    fork
      // ---- AW channel
      begin : aw_channel
        @(vif.master_cb);
        vif.master_cb.aw_id     <= t.id;
        vif.master_cb.aw_addr   <= t.addr;
        vif.master_cb.aw_len    <= t.len;
        vif.master_cb.aw_size   <= t.size;
        vif.master_cb.aw_burst  <= t.burst;
        vif.master_cb.aw_prot   <= t.prot;      // <-- NEW
        vif.master_cb.aw_cache  <= t.cache;     // <-- NEW
        vif.master_cb.aw_qos    <= t.qos;       // <-- NEW
        vif.master_cb.aw_region <= t.region;    // <-- NEW
        vif.master_cb.aw_user   <= t.user;
        vif.master_cb.aw_valid  <= 1'b1;
        // handshake happens on the posedge where READY is sampled high;
        // deassert VALID on the NEXT posedge (AXI-legal)
        do @(vif.master_cb); while (vif.master_cb.aw_ready !== 1'b1);
        vif.master_cb.aw_valid  <= 1'b0;
      end

      // ---- W channel
      begin : w_channel
        @(vif.master_cb);
        vif.master_cb.w_data    <= t.data;
        vif.master_cb.w_strb    <= t.strb;
        vif.master_cb.w_last    <= 1'b1;
        vif.master_cb.w_user    <= t.user;
        vif.master_cb.w_valid   <= 1'b1;
        do @(vif.master_cb); while (vif.master_cb.w_ready !== 1'b1);
        vif.master_cb.w_valid   <= 1'b0;
      end
    join

    // ---- optional response back-pressure
    repeat (t.resp_delay) @(vif.master_cb);

    // ---- B channel: drive b_ready via clocking block, sample payload via raw vif
    vif.master_cb.b_ready <= 1'b1;
    do @(posedge vif.clk); while (vif.b_valid !== 1'b1);  // raw sample
    t.resp      = vif.b_resp;
    t.resp_id   = vif.b_id;
    t.resp_user = vif.b_user;
    vif.master_cb.b_ready <= 1'b0;
  endtask

  // ----------------------------------------------------------------- read ---
  task drive_read(axi_seq_item t);
    @(vif.master_cb);
    vif.master_cb.ar_id     <= t.id;
    vif.master_cb.ar_addr   <= t.addr;
    vif.master_cb.ar_len    <= t.len;
    vif.master_cb.ar_size   <= t.size;
    vif.master_cb.ar_burst  <= t.burst;
    vif.master_cb.ar_prot   <= t.prot;      // <-- NEW
    vif.master_cb.ar_cache  <= t.cache;     // <-- NEW
    vif.master_cb.ar_qos    <= t.qos;       // <-- NEW
    vif.master_cb.ar_region <= t.region;    // <-- NEW
    vif.master_cb.ar_user   <= t.user;
    vif.master_cb.ar_valid  <= 1'b1;
    do @(vif.master_cb); while (vif.master_cb.ar_ready !== 1'b1);
    vif.master_cb.ar_valid  <= 1'b0;

    // ---- optional response back-pressure
    repeat (t.resp_delay) @(vif.master_cb);

    // ---- R channel: drive r_ready via clocking block, sample payload via raw vif
    vif.master_cb.r_ready <= 1'b1;
    do @(posedge vif.clk); while (vif.r_valid !== 1'b1);  // raw sample
    t.data      = vif.r_data;
    t.resp      = vif.r_resp;
    t.last      = vif.r_last;
    t.resp_id   = vif.r_id;
    t.resp_user = vif.r_user;
    vif.master_cb.r_ready <= 1'b0;
  endtask

endclass