class axi_apb_base_seq extends uvm_sequence #(axi_seq_item);

    `uvm_object_utils(axi_apb_base_seq)

    // Set by the test before start(): lets the sequence control the APB slave BFM
    apb_slave_driver apb_drv;

    int unsigned checks_done   = 0;
    int unsigned checks_failed = 0;

    function new(string name = "axi_apb_base_seq");
      super.new(name);
    endfunction

    // ------------------------------------------------------------- config knobs
    function void set_apb_waits(int unsigned min_w, int unsigned max_w);
      if (apb_drv == null) `uvm_fatal("SEQ", "apb_drv handle not set by the test")
      apb_drv.set_waits(min_w, max_w);
    endfunction

    function void set_apb_slverr(bit en);
      if (apb_drv == null) `uvm_fatal("SEQ", "apb_drv handle not set by the test")
      apb_drv.drive_slverr = en;
    endfunction

    function void preload_apb(bit [APB_ADDR_W-1:0] addr, bit [APB_DATA_W-1:0] data);
      if (apb_drv == null) `uvm_fatal("SEQ", "apb_drv handle not set by the test")
      apb_drv.preload(addr, data);
    endfunction

    // ---------------------------------------------------------------- write ----
    task do_write(input bit [AXI_ADDR_W-1:0] addr,
                  input bit [AXI_DATA_W-1:0] data,
                  input bit [AXI_ID_W-1:0]   id    = '0,
                  input bit [AXI_USER_W-1:0] user  = '0,
                  input int unsigned         delay = 0);
      axi_single_write_seq seq;
      seq = axi_single_write_seq::type_id::create("wr_seq");
      seq.addr       = addr;
      seq.data       = data;
      seq.id         = id;
      seq.user       = user;
      seq.resp_delay = delay;
      seq.start(get_sequencer());
      checks_done++;
      if (seq.resp !== 2'b00) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("write @0x%08h BRESP=%0b, expected OKAY", addr, seq.resp))
      end
      if (seq.resp_id !== id) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("write @0x%08h BID=0x%0h, expected 0x%0h",
                                    addr, seq.resp_id, id))
      end
      if (seq.resp_user !== user) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("write @0x%08h BUSER=0x%0h, expected 0x%0h",
                                    addr, seq.resp_user, user))
      end
    endtask

    // ----------------------------------------------------------------- read ----
    task do_read_check(input bit [AXI_ADDR_W-1:0] addr,
                       input bit [AXI_DATA_W-1:0] exp,
                       input bit [AXI_ID_W-1:0]   id    = '0,
                       input bit [AXI_USER_W-1:0] user  = '0,
                       input int unsigned         delay = 0);
      axi_single_read_seq seq;
      seq = axi_single_read_seq::type_id::create("rd_seq");
      seq.addr       = addr;
      seq.id         = id;
      seq.user       = user;
      seq.resp_delay = delay;
      seq.start(get_sequencer());
      checks_done++;
      if (seq.rdata !== exp) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("read @0x%08h returned 0x%08h, expected 0x%08h",
                                    addr, seq.rdata, exp))
      end
      if (seq.resp !== 2'b00) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("read @0x%08h RRESP=%0b, expected OKAY", addr, seq.resp))
      end
      if (seq.resp_id !== id) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("read @0x%08h RID=0x%0h, expected 0x%0h",
                                    addr, seq.resp_id, id))
      end
      if (seq.resp_user !== user) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("read @0x%08h RUSER=0x%0h, expected 0x%0h",
                                    addr, seq.resp_user, user))
      end
      if (seq.last !== 1'b1) begin
        checks_failed++;
        `uvm_error("SEQ", $sformatf("read @0x%08h RLAST=%0b, expected 1", addr, seq.last))
      end
    endtask

    // ------------------------------------------------------ raw read (no check)
    // Issue a read without checking the returned data ? used for the
    // simultaneous-priority scenario where the returned value must be
    // inspected by the caller (not compared against a fixed expectation).
    task do_read_raw(input  bit [AXI_ADDR_W-1:0] addr,
                     input  bit [AXI_ID_W-1:0]   id    = '0,
                     input  bit [AXI_USER_W-1:0] user  = '0,
                     input  int unsigned         delay = 0,
                     output bit [AXI_DATA_W-1:0] rdata);
      axi_single_read_seq seq;
      seq = axi_single_read_seq::type_id::create("rd_raw");
      seq.addr       = addr;
      seq.id         = id;
      seq.user       = user;
      seq.resp_delay = delay;
      seq.start(get_sequencer());
      rdata = seq.rdata;
    endtask

  endclass