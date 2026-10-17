// AXI master agent. is_active / get_is_active() is the built-in uvm_agent knob
// (default UVM_ACTIVE; a PASSIVE agent builds only the monitor).
class axi_agent extends uvm_agent;

  `uvm_component_utils(axi_agent)

  axi_sequencer    sqr;
  axi_driver       drv;
  axi_monitor      mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = axi_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = axi_sequencer::type_id::create("sqr", this);
      drv = axi_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
