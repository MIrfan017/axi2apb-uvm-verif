class axi_apb_directed_seq extends axi_apb_base_seq;

  `uvm_object_utils(axi_apb_directed_seq)

  function new(string name = "axi_apb_directed_seq");
    super.new(name);
  endfunction

  task body();

    // =========================================================================
    // T1: single write + read back, APB ready immediately
    // =========================================================================
    `uvm_info("DIRECTED", "T1: single write + read back, APB ready", UVM_LOW)
    set_apb_waits(0, 0);
    do_write      (32'h0000_0010, 32'hDEAD_BEEF, 6'h01);
    do_read_check (32'h0000_0010, 32'hDEAD_BEEF, 6'h01);

    // =========================================================================
    // T2: multiple addresses, read back in a different order
    // =========================================================================
    `uvm_info("DIRECTED", "T2: multiple addresses, out-of-order readback", UVM_LOW)
    do_write      (32'h0000_0100, 32'h1111_1111, 6'h02);
    do_write      (32'h0000_0104, 32'h2222_2222, 6'h03);
    do_write      (32'h0000_0108, 32'h3333_3333, 6'h04);
    do_write      (32'h0000_010C, 32'h4444_4444, 6'h05);
    do_read_check (32'h0000_010C, 32'h4444_4444, 6'h06);
    do_read_check (32'h0000_0100, 32'h1111_1111, 6'h07);
    do_read_check (32'h0000_0108, 32'h3333_3333, 6'h08);
    do_read_check (32'h0000_0104, 32'h2222_2222, 6'h09);

    // =========================================================================
    // T3: overwrite same address
    // =========================================================================
    `uvm_info("DIRECTED", "T3: overwrite same address", UVM_LOW)
    do_write      (32'h0000_0200, 32'hAAAA_0001, 6'h0A);
    do_write      (32'h0000_0200, 32'hBBBB_0002, 6'h0B);
    do_read_check (32'h0000_0200, 32'hBBBB_0002, 6'h0C);

    // =========================================================================
    // T4: data patterns
    // =========================================================================
    `uvm_info("DIRECTED", "T4: data patterns", UVM_LOW)
    do_write      (32'h0000_0300, 32'h0000_0000, 6'h10);   // all-zero
    do_read_check (32'h0000_0300, 32'h0000_0000, 6'h10);
    do_write      (32'h0000_0304, 32'hFFFF_FFFF, 6'h11);   // all-ones
    do_read_check (32'h0000_0304, 32'hFFFF_FFFF, 6'h11);
    do_write      (32'h0000_0308, 32'hAAAA_AAAA, 6'h12);   // alternating
    do_read_check (32'h0000_0308, 32'hAAAA_AAAA, 6'h12);
    do_write      (32'h0000_030C, 32'h5555_5555, 6'h13);   // alternating
    do_read_check (32'h0000_030C, 32'h5555_5555, 6'h13);
    do_write      (32'h0000_0310, 32'h0000_0001, 6'h14);   // walking-0
    do_read_check (32'h0000_0310, 32'h0000_0001, 6'h14);
    do_write      (32'h0000_0314, 32'h8000_0000, 6'h15);   // walking-31
    do_read_check (32'h0000_0314, 32'h8000_0000, 6'h15);

    // =========================================================================
    // T5: address extremes (including 0xFFFFFFFF)
    // =========================================================================
    `uvm_info("DIRECTED", "T5: address extremes", UVM_LOW)
    do_write      (32'h0000_0000, 32'h0123_4567, 6'h16);
    do_read_check (32'h0000_0000, 32'h0123_4567, 6'h16);
    do_write      (32'hFFFF_FFFC, 32'h89AB_CDEF, 6'h17);
    do_read_check (32'hFFFF_FFFC, 32'h89AB_CDEF, 6'h17);
    // 0xFFFFFFFF (aligned to 0xFFFFFFFC by RTL) ? covers cp_addr.max bin
    do_write      (32'hFFFF_FFFF, 32'hDEAD_FFFF, 6'h18);
    do_read_check (32'hFFFF_FFFF, 32'hDEAD_FFFF, 6'h18);

    // =========================================================================
    // T6: APB wait states
    // =========================================================================
    `uvm_info("DIRECTED", "T6: APB wait states 1, 2, 5", UVM_LOW)
    set_apb_waits(1, 1);
    do_write      (32'h0000_0400, 32'hC0DE_0001, 6'h20);
    do_read_check (32'h0000_0400, 32'hC0DE_0001, 6'h20);
    set_apb_waits(2, 2);
    do_write      (32'h0000_0404, 32'hC0DE_0002, 6'h21);
    do_read_check (32'h0000_0404, 32'hC0DE_0002, 6'h21);
    set_apb_waits(5, 5);
    do_write      (32'h0000_0408, 32'hC0DE_0003, 6'h22);
    do_read_check (32'h0000_0408, 32'hC0DE_0003, 6'h22);

    // =========================================================================
    // T7: back-pressure on B and R channels
    // =========================================================================
    `uvm_info("DIRECTED", "T7: BREADY/RREADY delayed 6 cycles", UVM_LOW)
    set_apb_waits(0, 0);
    do_write      (32'h0000_0500, 32'hFACE_B00C, 6'h23, '0, 6);
    do_read_check (32'h0000_0500, 32'hFACE_B00C, 6'h23, '0, 6);

    // =========================================================================
    // T8: read of a location preloaded in the APB slave
    // =========================================================================
    `uvm_info("DIRECTED", "T8: read of preloaded APB register", UVM_LOW)
    preload_apb   (32'h0000_0600, 32'h1234_ABCD);
    do_read_check (32'h0000_0600, 32'h1234_ABCD, 6'h30);

    // =========================================================================
    // T9: back-to-back mixed write/read traffic
    // =========================================================================
    `uvm_info("DIRECTED", "T9: back-to-back write/read mix", UVM_LOW)
    do_write      (32'h0000_0700, 32'hA0A0_A0A0, 6'h31);
    do_write      (32'h0000_0704, 32'hB1B1_B1B1, 6'h32);
    do_read_check (32'h0000_0700, 32'hA0A0_A0A0, 6'h33);
    do_write      (32'h0000_0700, 32'hC2C2_C2C2, 6'h34);
    do_read_check (32'h0000_0704, 32'hB1B1_B1B1, 6'h35);
    do_read_check (32'h0000_0700, 32'hC2C2_C2C2, 6'h36);

    // =========================================================================
    // T10: max ID value reuse
    // =========================================================================
    `uvm_info("DIRECTED", "T10: max ID value", UVM_LOW)
    do_write      (32'h0000_0800, 32'h7777_7777, 6'h3F);
    do_read_check (32'h0000_0800, 32'h7777_7777, 6'h3F);

    // =========================================================================
    // T11: ID + USER propagation on responses
    // =========================================================================
    `uvm_info("DIRECTED", "T11: ID + USER propagation", UVM_LOW)
    do_write      (32'h0000_0900, 32'hC0DE_0001, 6'h00, 6'h00);
    do_read_check (32'h0000_0900, 32'hC0DE_0001, 6'h00, 6'h00);
    do_write      (32'h0000_0904, 32'hAAAA_5555, 6'h2A, 6'h15);
    do_read_check (32'h0000_0904, 32'hAAAA_5555, 6'h2A, 6'h15);
    do_write      (32'h0000_0908, 32'h5555_AAAA, 6'h3F, 6'h3F);
    do_read_check (32'h0000_0908, 32'h5555_AAAA, 6'h3F, 6'h3F);

    // =========================================================================
    // T12: PSLVERR stimulus ? RTL ignores it, response must remain OKAY
    // =========================================================================
    `uvm_info("DIRECTED", "T12: PSLVERR high, expect OKAY", UVM_LOW)
    set_apb_waits(0, 0);
    set_apb_slverr(1'b1);
    do_write      (32'h0000_0A00, 32'h5A5A_5A5A, 6'h20);
    do_read_check (32'h0000_0A00, 32'h5A5A_5A5A, 6'h20);
    set_apb_slverr(1'b0);

        // =========================================================================
    // T13: simultaneous read + write ? read wins (RTL priority)
    // =========================================================================
    `uvm_info("DIRECTED", "T13: simultaneous RD+WR, read priority", UVM_LOW)
    begin
      bit [AXI_DATA_W-1:0] rd_value;
      set_apb_waits(2, 2);
      preload_apb(32'h0000_0B00, 32'hA5A5_0001);

      fork
        begin : rd_issue
          do_read_raw(32'h0000_0B00, 6'h30, '0, 0, rd_value);
        end
        begin : wr_issue
          do_write   (32'h0000_0B04, 32'hBEEF_DEAD, 6'h31);
        end
      join

      checks_done++;
      if (rd_value !== 32'hA5A5_0001) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("priority read returned 0x%08h, expected 0x%08h",
                                    rd_value, 32'hA5A5_0001))
      end
      do_read_check(32'h0000_0B04, 32'hBEEF_DEAD, 6'h32);
    end
    `uvm_info("DIRECTED",
              $sformatf("done: %0d checks, %0d failed", checks_done, checks_failed), UVM_LOW)
  endtask

endclass