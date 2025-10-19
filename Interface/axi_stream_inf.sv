


interface axi_str_inf();

parameter DATA_SIZE=32;

  logic reset_n;
  logic tvalid;   //AXI Stream valid signal
  logic tlast; 
  logic tready = 1; 
  logic [(DATA_SIZE-1):0] tdata;
  logic [((DATA_SIZE/8-1)):0] tkeep;   //AXI Stream Tkeep use valid data
  logic [(USER_SIZE-1):0] tuser;

modport master(input reset_n, tready, output tvalid, tlast, tready, tdata, tkeep, tuser);
modport slave(input reset_n, tvalid, tlast, tdata, tkeep, tuser, output tready);

endinterface 

