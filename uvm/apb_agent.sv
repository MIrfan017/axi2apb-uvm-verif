// APB sequencer stub: the APB slave is reactive and does not pull sequence items,
// but a sequencer is provided for spec compliance and future extendability.
class apb_sequencer extends uvm_sequencer #(apb_item);

  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass


class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  apb_slave_driver   drv;
  apb_monitor        mon;
  apb_sequencer      sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = apb_sequencer::type_id::create("sqr", this);
      drv = apb_slave_driver::type_id::create("drv", this);
    end
  endfunction

endclass