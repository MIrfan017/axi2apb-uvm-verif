// APB slave driver ? non-blocking drive/sample via slave_cb.
//
// Timing note: this RTL samples PREADY combinationally in the FSM and samples
// PRDATA on the same posedge where PREADY is high (sample_RDATA = PREADY).
// Therefore PRDATA must be valid on (or before) the posedge that drives PREADY=1.
// Strategy: hold PRDATA on the bus at all times during a read transaction,
//           and drive PREADY with the clocking block at the completion cycle.
class apb_slave_driver extends uvm_component;

  `uvm_component_utils(apb_slave_driver)

  apb_vif_t        vif;

  // ---- slave behaviour knobs
  int unsigned             min_wait = 0;
  int unsigned             max_wait = 0;
  bit                      drive_slverr = 1'b0;

  bit [APB_DATA_W-1:0]     mem [bit [APB_ADDR_W-1:0]];
  bit [APB_DATA_W-1:0]     default_rdata = '0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_vif_t)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NOVIF", "apb_slave_driver: apb_vif not found in config_db (set it in tb_top)")
  endfunction

  function void set_waits(int unsigned min_w, int unsigned max_w);
    min_wait = min_w;
    max_wait = max_w;
  endfunction

  function void preload(bit [APB_ADDR_W-1:0] addr, bit [APB_DATA_W-1:0] data);
    mem[addr] = data;
  endfunction

  function int unsigned pick_wait();
    if (max_wait <= min_wait) return min_wait;
    return $urandom_range(max_wait, min_wait);
  endfunction

  task run_phase(uvm_phase phase);
    bit          in_txn;
    int unsigned wcnt;
    int unsigned target;
    bit [APB_DATA_W-1:0] rdata_hold;

    in_txn     = 1'b0;
    wcnt       = 0;
    target     = 0;
    rdata_hold = '0;

    // idle values through the clocking block
    vif.slave_cb.pready  <= 1'b0;
    vif.slave_cb.prdata  <= '0;
    vif.slave_cb.pslverr <= 1'b0;

    wait (vif.rst_n === 1'b1);

    forever begin
      @(vif.slave_cb);

      // sample request inputs through the clocking block
      if (vif.slave_cb.psel === 1'b1 && vif.slave_cb.penable === 1'b1) begin
        if (!in_txn) begin
          in_txn = 1'b1;
          wcnt   = 0;
          target = pick_wait();
          // For reads, compute the return value ONCE at the start of the
          // transaction and drive it on the bus immediately, so it is stable
          // on every cycle of the APB access phase (including the PREADY=1
          // posedge where the DUT samples PRDATA).
          if (vif.slave_cb.pwrite === 1'b0) begin
            if (mem.exists(vif.slave_cb.paddr))
              rdata_hold = mem[vif.slave_cb.paddr];
            else
              rdata_hold = default_rdata;
            vif.slave_cb.prdata <= rdata_hold;
          end
        end

        if (wcnt >= target) begin
          // completion cycle
          vif.slave_cb.pready  <= 1'b1;
          vif.slave_cb.pslverr <= drive_slverr;
          if (vif.slave_cb.pwrite === 1'b1) begin
            mem[vif.slave_cb.paddr] = vif.slave_cb.pwdata;
          end
          in_txn = 1'b0;
        end else begin
          vif.slave_cb.pready  <= 1'b0;
          wcnt++;
        end
      end else begin
        vif.slave_cb.pready  <= 1'b0;
        vif.slave_cb.pslverr <= 1'b0;
        in_txn = 1'b0;
        wcnt   = 0;
      end
    end
  endtask

endclass