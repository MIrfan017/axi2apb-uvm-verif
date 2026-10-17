// Top-level testbench: clock/reset, interfaces, DUT, UVM start-up.
`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_apb_pkg::*;

  logic clk;
  logic rst_n;

  // ---------------- clock / reset ----------------
  initial clk = 1'b0;
  always #5 clk = ~clk;                       // 100 MHz

  initial begin
    rst_n = 1'b0;
    repeat (10) @(negedge clk);
    rst_n = 1'b1;
  end

  // ---------------- interfaces ----------------
  AXI_BUS #(
    .AXI_ADDR_WIDTH (AXI_ADDR_W),
    .AXI_DATA_WIDTH (AXI_DATA_W),
    .AXI_ID_WIDTH   (AXI_ID_W),
    .AXI_USER_WIDTH (AXI_USER_W)
  ) axi_if (.clk(clk), .rst_n(rst_n));

  APB_BUS #(
    .APB_ADDR_WIDTH (APB_ADDR_W),
    .APB_DATA_WIDTH (APB_DATA_W)
  ) apb_if (.clk(clk), .rst_n(rst_n));

  // ---------------- DUT ----------------
  axi2apb_wrap #(
    .AXI_ADDR_WIDTH (AXI_ADDR_W),
    .AXI_DATA_WIDTH (AXI_DATA_W),
    .AXI_USER_WIDTH (AXI_USER_W),
    .AXI_ID_WIDTH   (AXI_ID_W),
    .APB_ADDR_WIDTH (APB_ADDR_W),
    .APB_DATA_WIDTH (APB_DATA_W)
  ) dut (
    .clk_i      (clk),
    .rst_ni     (rst_n),
    .test_en_i  (1'b0),
    .axi_slave  (axi_if),
    .apb_master (apb_if)
  );

  // ---------------- UVM start ----------------
  initial begin
    // every driver / monitor under the test gets its interface with get() in build_phase
    uvm_config_db#(axi_vif_t)::set(null, "uvm_test_top.*", "axi_vif", axi_if);
    uvm_config_db#(apb_vif_t)::set(null, "uvm_test_top.*", "apb_vif", apb_if);
    run_test();                               // test chosen with +UVM_TESTNAME
  end

  // ---------------- optional waveform (+WAVE) ----------------
  initial begin
    if ($test$plusargs("WAVE")) begin
`ifdef VCS
      $vcdplusfile("waveform.vpd");
      $vcdpluson(0, tb_top);
`else
      $dumpfile("waves.vcd");
      $dumpvars(0, tb_top);
`endif
    end
  end

endmodule
