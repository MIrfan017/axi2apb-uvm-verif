// One completed APB transfer, as seen by the APB monitor
class apb_item extends uvm_sequence_item;

  bit                      write;
  bit [APB_ADDR_W-1:0]     addr;
  bit [APB_DATA_W-1:0]     data;         // write: PWDATA / read: PRDATA
  bit                      slverr;
  int unsigned             wait_cycles;  // PENABLE cycles with PREADY low

  `uvm_object_utils(apb_item)

  function new(string name = "apb_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h slverr=%0b waits=%0d",
                     write ? "WR" : "RD", addr, data, slverr, wait_cycles);
  endfunction

endclass
