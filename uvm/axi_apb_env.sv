class axi_apb_env extends uvm_env;

  `uvm_component_utils(axi_apb_env)

  axi_agent            axi_agt;
  apb_agent            apb_agt;
  axi_apb_scoreboard   sb;
  axi_coverage         axi_cov;
  apb_coverage         apb_cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi_agt = axi_agent::type_id::create("axi_agt", this);
    apb_agt = apb_agent::type_id::create("apb_agt", this);
    sb      = axi_apb_scoreboard::type_id::create("sb", this);
    axi_cov = axi_coverage::type_id::create("axi_cov", this);
    apb_cov = apb_coverage::type_id::create("apb_cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    axi_agt.mon.ap.connect(sb.axi_export);
    apb_agt.mon.ap.connect(sb.apb_export);
    axi_agt.mon.ap.connect(axi_cov.analysis_export);
    apb_agt.mon.ap.connect(apb_cov.analysis_export);
  endfunction

endclass
