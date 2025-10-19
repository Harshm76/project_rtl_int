module register_memory_axi_lite #(
  DATA_SIZE = 32,
  ADDR_SIZE = 32,  // for 32K registers (2^15)
  ID_SIZE   = 32
)(
  input  logic clk,
  axi_lite_inf.slave axi_if
);

  // ---------------- Memory Declarations ----------------
  bit [DATA_SIZE-1:0] connection_config_mem [0:32767];
  bit [DATA_SIZE-1:0] output_port           [0:31];
  bit [DATA_SIZE-1:0] crc_mem               [0:31];

  bit [ADDR_SIZE-1:0] awaddr;
  bit [ID_SIZE-1:0] awid;
  bit [ID_SIZE-1:0] arid;
  bit [DATA_SIZE-1:0] rdata;
  bit [1:0] bresp;
  bit [1:0] rresp;
  // ---------------- Write Logic ----------------
  always_ff @(posedge clk) begin
    if (!axi_if.reset_n) begin
      axi_if.awready <= 1'b0;
      axi_if.wready  <= 1'b0;
      axi_if.bvalid  <= 1'b0;
    end
    else begin
      axi_if.awready <= 1'b1;
      axi_if.wready  <= 1'b1;
      axi_if.bvalid <= 1'b0;
      fork
        @(posedge clk iff axi_if.awvalid);
		if(!axi_if.awready) begin
		  @(posedge clk iff axi_if.awready);
		end
        @(posedge clk iff axi_if.wvalid);
		if(!axi_if.wready) begin
		  @(posedge clk iff axi_if.wready);
		end
	  join_any
	  awaddr = axi_if,addr;
	  awid = axi_if.awid;
	  wait fork;
        axi_if.bid    <= awid;
        axi_if.bvalid <= 1'b1;

        // -------- Address Decode --------
		if(awaddr inside {[3000:3099]}) begin
		    output_port[awaddr[4:0]-15'h3000] <= axi_if.wdata;
            bresp  <= 2'b00;
		end
		else if(awaddr inside {[3100:3999]}) begin
		    crc_mem[axi_if.awaddr[4:0]-15'h3100] <= axi_if.wdata;
            bresp  <= 2'b00;
		end
		else if(awaddr inside {[4000:]}) begin
		    connection_config_mem[axi_if.awaddr[16:0]-15'h4000] <= axi_if.wdata;
            bresp  <= 2'b00;		
		end
		else begin
		    bresp <= 2'b10;
		end
		@(posedge clk iff axi_if.bready);
        axi_if.bvalid <= 1'b0;
    end
  end

  // ---------------- Read Logic ----------------
  always_ff @(posedge clk) begin
    if (!axi_if.reset_n) begin
      axi_if.arready <= 1'b0;
      axi_if.rvalid  <= 1'b0;
    end
    else begin
      axi_if.arready <= 1'b1;
      axi_if.rvalid <= 1'b0;
      fork
        @(posedge clk iff axi_if.arvalid);
		if(!axi_if.arready) begin
		  @(posedge clk iff axi_if.arready);
		end
      join

        // -------- Address Decode --------
		if(araddr inside {[3000:3099]}) begin
		    rdata <= output_port[araddr[4:0]-15'h3000];
            rresp <= 2'b00;
		end
		else if(araddr inside {[3100:3999]}) begin
		    rdata <= crc_mem[axi_if.araddr[4:0]-15'h3100];
            rresp <= 2'b00;
		end
		else if(araddr inside {[4000:]}) begin
		    rdata <= connection_config_mem[axi_if.araddr[16:0]-15'h4000];
            rresp <= 2'b00;		
		end
		else begin
		    rdata <= 0;
		    rresp <= 2'b10;
		end
		axi_if.rdata  <= rdata;
        axi_if.rid    <= arid;		
		axi_if.rvalid <= 1'b1;
        axi_if.rresp  <= rresp;
        axi_if.rlast  <= 1'b1;
		@(posedge clk iff axi_if.rready);
		axi_if.rvalid <= 1'b0;
        axi_if.rlast  <= 1'b0;
      end
  end
task parser;


  end

endtask 
endmodule
