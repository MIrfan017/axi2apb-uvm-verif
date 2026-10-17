// ============================================================================
// Directed test: runs the directed sequence once, directly on the AXI sequencer.
// ============================================================================
class axi_apb_directed_test extends axi_apb_base_test;

  `uvm_component_utils(axi_apb_directed_test)

  function new(string name = "axi_apb_directed_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_apb_directed_seq seq;
    int unsigned         quiet_cycles;

    phase.raise_objection(this, "directed test running");

    seq = axi_apb_directed_seq::type_id::create("seq");
    seq.apb_drv = env.apb_agt.drv;
    seq.start(env.axi_agt.sqr);

    // Drain: wait for both scoreboard queues to stay empty for 50 cycles.
    // Uses scoreboard's public is_idle() helper (queues are protected).
    quiet_cycles = 0;
    while (quiet_cycles < 50) begin
      @(posedge env.axi_agt.drv.vif.clk);
      if (env.sb.is_idle()) quiet_cycles++;
      else                  quiet_cycles = 0;
    end

    `uvm_info("DIRECTED_TEST",
              $sformatf("directed sequence done (checks=%0d failed=%0d)",
                        seq.checks_done, seq.checks_failed), UVM_LOW)

    phase.drop_objection(this, "directed test done");
  endtask

endclass