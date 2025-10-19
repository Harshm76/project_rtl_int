


interface axi_lite_inf();

parameter DATA_SIZE=32;
parameter ADDR_SIAE=32;

  logic reset_n;
  logic awvalid;   //AXI Stream valid signal
  logic awready;
  logic [ADDR_SIAE-1:0] awaddr;
  logic awid;
  logic awsize;
  logic awlen;
  logic awburst;  
  
  logic wvalid;
  logic wready;
  logic [DATA_SIZE-1:0] wdata;
  logic wlast;
  
  logic bready;
  logic bvalid;
  logic bresp;
  logic bid;

  logic arready;
  logic arvalid;
  logic [ADDR_SIAE-1:0] araddr;
  logic arid;
  logic arsize;
  
  logic rvalid;
  logic rready;
  logic [DATA_SIZE-1:0] rdata;
  logic rlast;
  logic rid;
  logic rresp;

modport slvae(input    reset_n, awvalid, awaddr, awid, awsize,
               input   wvalid, wdata, wlast,bready,
			   input   arvalid, araddr, arid, arsize,rready,
			   output  bvalid,bresp,bid,
			   output  rvalid, rdata, rlast, rid, rresp, 
               output  arready, awready, wready);
			   
modport master(input  reset_n, awready, wready, bvalid, bresp, bid,
           arready, rvalid, rdata, rlast, rid, rresp,
    output awvalid, awaddr, awid, awsize,
           wvalid, wdata, wlast, bready,
           arvalid, araddr, arid, arsize, rready);

endinterface 

