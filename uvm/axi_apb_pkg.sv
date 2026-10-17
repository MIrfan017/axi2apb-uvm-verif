// ============================================================================
// axi_apb_pkg : single package that pulls in the whole UVM environment
// Compile order: interfaces (tb/) -> rtl/ -> this package -> tb/tb_top.sv
// Needs +incdir+uvm +incdir+sequences +incdir+tests
// ============================================================================
package axi_apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---------------- global parameters (must match tb_top / DUT) -------------
  localparam int AXI_ADDR_W = 32;
  localparam int AXI_DATA_W = 32;
  localparam int AXI_ID_W   = 6;
  localparam int AXI_USER_W = 6;
  localparam int APB_ADDR_W = 32;
  localparam int APB_DATA_W = 32;

  typedef virtual AXI_BUS #(
    .AXI_ADDR_WIDTH (AXI_ADDR_W),
    .AXI_DATA_WIDTH (AXI_DATA_W),
    .AXI_ID_WIDTH   (AXI_ID_W),
    .AXI_USER_WIDTH (AXI_USER_W)
  ) axi_vif_t;

  typedef virtual APB_BUS #(
    .APB_ADDR_WIDTH (APB_ADDR_W),
    .APB_DATA_WIDTH (APB_DATA_W)
  ) apb_vif_t;

  // ---------------- transaction items ---------------------------------------
  `include "axi_seq_item.sv"
  `include "apb_item.sv"

  // ---------------- AXI master agent ----------------------------------------
  `include "axi_sequencer.sv"
  `include "axi_driver.sv"
  `include "axi_monitor.sv"
  `include "axi_agent.sv"

  // ---------------- APB slave agent -----------------------------------------
  `include "apb_slave_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"

  // ---------------- environment ---------------------------------------------
  `include "axi_apb_scoreboard.sv"
  `include "axi_apb_coverage.sv"
  `include "axi_apb_env.sv"

  // ---------------- sequences -----------------------------------------------
  `include "axi_single_write_seq.sv"
  `include "axi_single_read_seq.sv"
  `include "axi_apb_base_seq.sv"
  `include "axi_apb_directed_seq.sv"
  `include "axi_apb_random_seq.sv"

  // ---------------- tests ---------------------------------------------------
  `include "axi_apb_base_test.sv"
  `include "axi_apb_directed_test.sv"
  `include "axi_apb_random_test.sv" 

endpackage
