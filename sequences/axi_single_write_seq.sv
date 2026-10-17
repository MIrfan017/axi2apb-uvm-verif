// One single-beat AXI write. Set the fields, then start() on the AXI sequencer.
class axi_single_write_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(axi_single_write_seq)

  bit [AXI_ADDR_W-1:0]   addr;
  bit [AXI_DATA_W-1:0]   data;
  bit [AXI_ID_W-1:0]     id         = '0;
  bit [AXI_USER_W-1:0]   user       = '0;
  int unsigned           resp_delay = 0;
  // captured after the sequence completes
  bit [1:0]              resp;
  bit [AXI_ID_W-1:0]     resp_id;
  bit [AXI_USER_W-1:0]   resp_user;

  function new(string name = "axi_single_write_seq");
    super.new(name);
  endfunction

  task body();
    axi_seq_item t;
    t = axi_seq_item::type_id::create("wr_item");
    start_item(t);
    t.write      = 1'b1;
    t.addr       = addr;
    t.data       = data;
    t.strb       = '1;
    t.id         = id;
    t.user       = user;
    t.resp_delay = resp_delay;
    finish_item(t);
    resp      = t.resp;
    resp_id   = t.resp_id;
    resp_user = t.resp_user;
    `uvm_info(get_type_name(),
              $sformatf("WRITE addr=0x%08h data=0x%08h id=0x%0h user=0x%0h bresp=%0b bid=0x%0h buser=0x%0h",
                        addr, data, id, user, resp, resp_id, resp_user), UVM_MEDIUM)
  endtask

endclass