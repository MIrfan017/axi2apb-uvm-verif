// Functional coverage for the directed + random phase.
class axi_coverage extends uvm_subscriber #(axi_seq_item);

  `uvm_component_utils(axi_coverage)

  protected axi_seq_item item;
  protected axi_seq_item prev_item;
  protected bit          have_prev;

  covergroup axi_cg;
    option.per_instance = 1;

    cp_dir : coverpoint item.write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cp_addr : coverpoint item.addr {
      bins zero = {32'h0000_0000};
      bins max  = {32'hFFFF_FFFF};
      bins low  = {[32'h0000_0001 : 32'h0000_00FF]};
      bins mid  = {[32'h0000_0100 : 32'h0000_FFFE]};
      bins high = {[32'h0001_0000 : 32'hFFFF_FFFE]};
    }

    // unaligned-access coverage: sample low 2 bits of the address directly
    cp_addr_unaligned : coverpoint item.addr[1:0] {
      bins aligned  = {2'b00};
      bins offset_1 = {2'b01};
      bins offset_2 = {2'b10};
      bins offset_3 = {2'b11};
    }

    cp_data : coverpoint item.data {
      bins zero       = {32'h0000_0000};
      bins ones       = {32'hFFFF_FFFF};
      bins alt_aa     = {32'hAAAA_AAAA};
      bins alt_55     = {32'h5555_5555};
      bins walking_0  = {32'h0000_0001};
      bins walking_31 = {32'h8000_0000};
      bins other      = default;
    }

 
    cp_resp : coverpoint item.resp {
      bins okay = {2'b00};
    }

    cp_id : coverpoint item.id {
      bins zero = {0};
      bins one  = {1};
      bins misc = default;
    }

    cp_user : coverpoint item.user {
      bins zero = {0};
      bins max  = {{AXI_USER_W{1'b1}}};
      bins misc = default;
    }

    cp_backpressure : coverpoint item.resp_delay {
      bins none  = {0};
      bins one   = {1};
      bins few   = {[2:3]};
      bins many  = {[4:$]};
    }

    cp_b2b : coverpoint item.write iff (have_prev) {
      bins b2b_read  = {1'b0} iff (prev_item.write == 1'b0);
      bins b2b_write = {1'b1} iff (prev_item.write == 1'b1);
    }

    x_dir_addr    : cross cp_dir, cp_addr;
    x_dir_data    : cross cp_dir, cp_data;
    x_dir_bp      : cross cp_dir, cp_backpressure;
    x_dir_resp_bp : cross cp_dir, cp_resp, cp_backpressure;
    x_dir_id      : cross cp_dir, cp_id;
    x_dir_user    : cross cp_dir, cp_user;
    x_dir_addr_un : cross cp_dir, cp_addr_unaligned;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_cg = new();
    have_prev = 1'b0;
  endfunction

  function void write(axi_seq_item t);
    item = t;
    axi_cg.sample();
    prev_item = t;
    have_prev = 1'b1;
  endfunction

endclass


class apb_coverage extends uvm_subscriber #(apb_item);

  `uvm_component_utils(apb_coverage)

  protected apb_item item;

  covergroup apb_cg;
    option.per_instance = 1;

    cp_dir : coverpoint item.write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cp_waits : coverpoint item.wait_cycles {
      bins few  = {[2:3]};
      bins low  = {[0:1]};   // 0 aur 1 dono yahan aayenge
      bins many = {[4:$]};
    }

    cp_slverr : coverpoint item.slverr {
      bins low  = {1'b0};
      bins high = {1'b1};
    }

    x_dir_waits  : cross cp_dir, cp_waits;
    x_dir_slverr : cross cp_dir, cp_slverr;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_item t);
    item = t;
    apb_cg.sample();
  endfunction

endclass