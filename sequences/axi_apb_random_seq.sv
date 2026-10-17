class axi_apb_random_base_seq extends axi_apb_base_seq;

  `uvm_object_utils(axi_apb_random_base_seq)

  rand int unsigned num_trans;
  constraint c_num_trans { num_trans inside {[80:150]}; }

  rand int unsigned apb_min_wait;
  rand int unsigned apb_max_wait;
  constraint c_apb_waits {
    apb_min_wait inside {[0:2]};
    apb_max_wait inside {[apb_min_wait : 6]};
  }

  function new(string name = "axi_apb_random_base_seq");
    super.new(name);
  endfunction

  // User must override this to constrain `req`
  virtual function void apply_constraints(axi_seq_item req);
  endfunction

  task body();
    axi_seq_item req;
    int unsigned n_wr, n_rd;

    if (!this.randomize()) `uvm_fatal("RAND_SEQ", "Top-level randomize failed")
    
    set_apb_waits(apb_min_wait, apb_max_wait);
    n_wr = 0; n_rd = 0;

    for (int i = 0; i < num_trans; i++) begin
      req = axi_seq_item::type_id::create($sformatf("req_%0d", i));
      
      // Base constraints (common to all)
      if (!req.randomize() with {
            strb   == '1;
            len    == 8'd0;
            size   == 3'd2;
            burst  == 2'b01;
            prot   inside {[0:7]};
            cache  inside {[0:15]};
            qos    inside {[0:15]};
            region inside {[0:15]};
          }) begin
        `uvm_error("RAND_SEQ", $sformatf("Base randomize failed at iter %0d", i))
        continue;
      end

      // Apply specific sequence constraints
      apply_constraints(req);
      if (!req.randomize()) begin
         `uvm_error("RAND_SEQ", "Specific randomize failed")
         continue;
      end

      // Dispatch to driver
      if (req.write) begin
        do_write(req.addr, req.data, req.id, req.user, req.resp_delay);
        n_wr++;
      end else begin
        bit [AXI_DATA_W-1:0] dummy;
        do_read_raw(req.addr, req.id, req.user, req.resp_delay, dummy);
        n_rd++;
      end

      // Randomize APB wait-state band every 5 transactions
      if (((i + 1) % 5) == 0) begin
        set_apb_waits($urandom_range(0, 2), $urandom_range(2, 6));
      end
    end
    
    `uvm_info("RAND_SEQ", $sformatf("Done: %0d WR, %0d RD, checks_done=%0d, failed=%0d", n_wr, n_rd, checks_done, checks_failed), UVM_LOW)
  endtask
endclass

// ----------------------------------------------------------------------------
// 2. FULLY RANDOM (Mixed Traffic)
// ----------------------------------------------------------------------------
class axi_apb_rand_mixed_seq extends axi_apb_random_base_seq;
  `uvm_object_utils(axi_apb_rand_mixed_seq)
  function new(string name = "axi_apb_rand_mixed_seq"); super.new(name); endfunction

  virtual function void apply_constraints(axi_seq_item req);
    void'(req.randomize() with { 
      addr inside {[0 : 32'hFFFF_FFFF]}; 
      resp_delay inside {[0:8]}; 
    });
  endfunction
endclass

// ----------------------------------------------------------------------------
// 3. WRITE HEAVY
// ----------------------------------------------------------------------------
class axi_apb_rand_write_heavy_seq extends axi_apb_random_base_seq;
  `uvm_object_utils(axi_apb_rand_write_heavy_seq)
  function new(string name = "axi_apb_rand_write_heavy_seq"); super.new(name); endfunction

  virtual function void apply_constraints(axi_seq_item req);
    void'(req.randomize() with { 
      write == 1'b1; 
      addr inside {[0 : 32'h0000_FFFF]}; // Focus on lower memory
    });
  endfunction
endclass

// ----------------------------------------------------------------------------
// 4. READ HEAVY
// ----------------------------------------------------------------------------
class axi_apb_rand_read_heavy_seq extends axi_apb_random_base_seq;
  `uvm_object_utils(axi_apb_rand_read_heavy_seq)
  function new(string name = "axi_apb_rand_read_heavy_seq"); super.new(name); endfunction

  virtual function void apply_constraints(axi_seq_item req);
    void'(req.randomize() with { 
      write == 1'b0; 
      addr inside {[32'h1000_0000 : 32'hFFFF_FFFF]}; // Focus on higher memory
    });
  endfunction
endclass

// ----------------------------------------------------------------------------
// 5. MAX BACKPRESSURE
// ----------------------------------------------------------------------------
class axi_apb_rand_backpressure_seq extends axi_apb_random_base_seq;
  `uvm_object_utils(axi_apb_rand_backpressure_seq)
  function new(string name = "axi_apb_rand_backpressure_seq"); super.new(name); endfunction

  virtual function void apply_constraints(axi_seq_item req);
    void'(req.randomize() with { 
      resp_delay inside {[5:15]}; // Force long BREADY/RREADY delays
    });
  endfunction
endclass

// ----------------------------------------------------------------------------
// 6. EDGE CASES (Unaligned + Max/Min Address)
// ----------------------------------------------------------------------------
class axi_apb_rand_edge_seq extends axi_apb_random_base_seq;
  `uvm_object_utils(axi_apb_rand_edge_seq)
  function new(string name = "axi_apb_rand_edge_seq"); super.new(name); endfunction

  virtual function void apply_constraints(axi_seq_item req);
    void'(req.randomize() with { 
      // Force unaligned addresses and extremes
      (addr == 32'h0000_0000) || 
      (addr == 32'hFFFF_FFFF) || 
      (addr % 4 != 0); // Unaligned
    });
  endfunction
endclass