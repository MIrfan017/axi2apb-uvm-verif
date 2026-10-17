// APB bus interface (matches the signal names used by axi2apb_wrap)

interface APB_BUS #(
    parameter int APB_ADDR_WIDTH = 32,
    parameter int APB_DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);

    logic [APB_ADDR_WIDTH-1:0]    paddr;
    logic [APB_DATA_WIDTH-1:0]    pwdata;
    logic                         pwrite;
    logic                         psel;
    logic                         penable;
    logic [APB_DATA_WIDTH-1:0]    prdata;
    logic                         pready;
    logic                         pslverr;

    // ============================================================
    // Slave clocking block: driver uses this for drive and sample.
    // ============================================================
    clocking slave_cb @(posedge clk);
    default input #1step output #0;   // <-- output #0 (NBA ke baad drive)
    input  paddr, pwdata, pwrite, psel, penable;
    output prdata, pready, pslverr;
    endclocking

    // ============================================================
    // Monitor clocking block: passive sample on posedge.
    // ============================================================
    clocking monitor_cb @(posedge clk);
        default input #1step;

        input paddr, pwdata, pwrite, psel, penable,
              prdata, pready, pslverr;
    endclocking

    // ============================================================
    // Modports
    // ============================================================
    modport Master (
        output paddr, pwdata, pwrite, psel, penable,
        input  prdata, pready, pslverr
    );

    modport Slave (
        input  paddr, pwdata, pwrite, psel, penable,
        output prdata, pready, pslverr
    );

    modport Monitor (
        input paddr, pwdata, pwrite, psel, penable, prdata, pready, pslverr
    );

endinterface