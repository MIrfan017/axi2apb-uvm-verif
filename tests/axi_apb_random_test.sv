class axi_apb_random_base_test extends axi_apb_base_test;

  function new(string name = "axi_apb_random_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function axi_apb_base_seq create_seq();
    return null; // Override this
  endfunction

  task run_phase(uvm_phase phase);
    axi_apb_base_seq seq;
    int unsigned quiet_cycles;

    phase.raise_objection(this, "Random test running");

    seq = create_seq();
    seq.apb_drv = env.apb_agt.drv;
    seq.start(env.axi_agt.sqr);

    // Drain logic
    quiet_cycles = 0;
    while (quiet_cycles < 50) begin
      @(posedge env.axi_agt.drv.vif.clk);
      if (env.sb.is_idle()) quiet_cycles++;
      else                  quiet_cycles = 0;
    end

    phase.drop_objection(this, "Random test done");
  endtask
endclass


// ----------------------------------------------------------------------------
// 1. FULLY RANDOM TEST
// ----------------------------------------------------------------------------
class axi_apb_rand_mixed_test extends axi_apb_random_base_test;
  `uvm_component_utils(axi_apb_rand_mixed_test)
  function new(string name="axi_apb_rand_mixed_test", uvm_component parent=null); super.new(name,parent); endfunction
  virtual function axi_apb_base_seq create_seq();
    axi_apb_rand_mixed_seq s = axi_apb_rand_mixed_seq::type_id::create("seq");
    return s;
  endfunction
endclass

// ----------------------------------------------------------------------------
// 2. WRITE HEAVY TEST
// ----------------------------------------------------------------------------
class axi_apb_rand_write_heavy_test extends axi_apb_random_base_test;
  `uvm_component_utils(axi_apb_rand_write_heavy_test)
  function new(string name="axi_apb_rand_write_heavy_test", uvm_component parent=null); super.new(name,parent); endfunction
  virtual function axi_apb_base_seq create_seq();
    axi_apb_rand_write_heavy_seq s = axi_apb_rand_write_heavy_seq::type_id::create("seq");
    return s;
  endfunction
endclass

// ----------------------------------------------------------------------------
// 3. READ HEAVY TEST
// ----------------------------------------------------------------------------
class axi_apb_rand_read_heavy_test extends axi_apb_random_base_test;
  `uvm_component_utils(axi_apb_rand_read_heavy_test)
  function new(string name="axi_apb_rand_read_heavy_test", uvm_component parent=null); super.new(name,parent); endfunction
  virtual function axi_apb_base_seq create_seq();
    axi_apb_rand_read_heavy_seq s = axi_apb_rand_read_heavy_seq::type_id::create("seq");
    return s;
  endfunction
endclass

// ----------------------------------------------------------------------------
// 4. MAX BACKPRESSURE TEST
// ----------------------------------------------------------------------------
class axi_apb_rand_backpressure_test extends axi_apb_random_base_test;
  `uvm_component_utils(axi_apb_rand_backpressure_test)
  function new(string name="axi_apb_rand_backpressure_test", uvm_component parent=null); super.new(name,parent); endfunction
  virtual function axi_apb_base_seq create_seq();
    axi_apb_rand_backpressure_seq s = axi_apb_rand_backpressure_seq::type_id::create("seq");
    return s;
  endfunction
endclass

// ----------------------------------------------------------------------------
// 5. EDGE CASES TEST
// ----------------------------------------------------------------------------
class axi_apb_rand_edge_test extends axi_apb_random_base_test;
  `uvm_component_utils(axi_apb_rand_edge_test)
  function new(string name="axi_apb_rand_edge_test", uvm_component parent=null); super.new(name,parent); endfunction
  virtual function axi_apb_base_seq create_seq();
    axi_apb_rand_edge_seq s = axi_apb_rand_edge_seq::type_id::create("seq");
    return s;
  endfunction
endclass