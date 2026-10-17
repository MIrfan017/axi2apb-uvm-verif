// One single-beat AXI read. rdata / resp are valid after the sequence is done.
class axi_single_read_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(axi_single_read_seq)

  bit [AXI_ADDR_W-1:0]   addr;
  bit [AXI_ID_W-1:0]     id         = '0;
  bit [AXI_USER_W-1:0]   user       = '0;
  int unsigned           resp_delay = 0;
  // captured after the sequence completes
  bit [AXI_DATA_W-1:0]   rdata;
  bit [1:0]              resp;
  bit [AXI_ID_W-1:0]     resp_id;
  bit [AXI_USER_W-1:0]   resp_user;
  bit                    last;

  function new(string name = "axi_single_read_seq");
    super.new(name);
  endfunction

  task body();
    axi_seq_item t;
    t = axi_seq_item::type_id::create("rd_item");
    start_item(t);
    t.write      = 1'b0;
    t.addr       = addr;
    t.id         = id;
    t.user       = user;
    t.resp_delay = resp_delay;
    finish_item(t);
    rdata     = t.data;
    resp      = t.resp;
    resp_id   = t.resp_id;
    resp_user = t.resp_user;
    last      = t.last;
    `uvm_info(get_type_name(),
              $sformatf("READ  addr=0x%08h data=0x%08h id=0x%0h user=0x%0h rresp=%0b rid=0x%0h ruser=0x%0h last=%0b",
                        addr, rdata, id, user, resp, resp_id, resp_user, last), UVM_MEDIUM)
  endtask

endclass