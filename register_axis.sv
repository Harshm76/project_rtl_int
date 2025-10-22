module register_memory_axi_lite #(
  int DATA_SIZE = 32,
  int ADDR_SIZE = 32,  // for 32K registers (2^15)
  int ID_SIZE   = 32
  int AXIS_DATA_SIZE = 32,
  int USER_SIZE = 16    
)(
  input  logic clk,
  axi_lite_inf.slave #(DATA_SIZE, ADDR_SIZE, ID_SIZE) axi_if,
  axi_str_inf.slave #(AXIS_DATA_SIZE,USER_SIZE) axis_in_inf
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

// ---------------- AXI-Stream Packet Capture ---------------- 

  // Queues
  logic [AXIS_DATA_SIZE-1:0] axis_pkt_temp_tdata_q[NUM_PORTS][$];
  logic [USER_SIZE-1:0]      axis_pkt_temp_tuser_q[NUM_PORTS][$];

// Step 1: make_packet()
  task make_packet();
    foreach (axis_in_inf[i]) begin
      fork
        forever begin
          @(posedge clk iff axis_in_inf[i].tvalid);
          axis_pkt_temp_tdata_q[i].push_back(axis_in_inf[i].tdata);
          axis_pkt_temp_tuser_q[i].push_back(axis_in_inf[i].tuser);

          if (axis_in_inf[i].tlast)
            $display("[%0t] Packet captured from port %0d, size=%0d", $time, i, axis_pkt_temp_tdata_q[i].size());
        end
      join_none
    end
  endtask

  // Step 2: buffer()
  logic [AXIS_DATA_SIZE-1:0] axis_buffer_tdata_q[NUM_PORTS][$];
  logic [USER_SIZE-1:0]      axis_buffer_tuser_q[NUM_PORTS][$];

  task buffer();
    forever begin
      foreach (axis_in_inf[i]) begin
        wait(axis_pkt_temp_tdata_q[i].size() != 0);
        axis_buffer_tdata_q[i].push_back(axis_pkt_temp_tdata_q[i].pop_front());
        axis_buffer_tuser_q[i].push_back(axis_pkt_temp_tuser_q[i].pop_front());
      end
      @(posedge clk);
    end
  endtask
initial begin
fork
      make_packet();
      buffer();
      parser();
    join_none
end
task parser;

     //check interface axi stream
     //read memory (register)
     //check packet is valid or not
  int index;
    bit [DATA_SIZE-1:0] expected_connection;
    bit [DATA_SIZE-1:0] expected_output;
    bit [DATA_SIZE-1:0] expected_crc;
    connection_addr_t connection_addr;
    logic [AXIS_DATA_SIZE-1:0] tdata_packet;
    logic [USER_SIZE-1:0]      tuser_packet;

    forever begin
      foreach (axis_buffer_tdata_q[i]) begin
        wait(axis_buffer_tdata_q[i].size() != 0);
        tdata_packet = axis_buffer_tdata_q[i].pop_front();
        tuser_packet = axis_buffer_tuser_q[i].pop_front();

        // Extract VLAN and Port
        connection_addr.vlan    = tuser_packet[USER_SIZE-1 -: 12];
        connection_addr.port_id = tuser_packet[2:0];
        index = (connection_addr.port_id << 12) | connection_addr.vlan;

        expected_connection = connection_config_mem[index];
        expected_output     = output_port[connection_addr.port_id];
        expected_crc        = crc_mem[connection_addr.port_id];            // Check packet against memories
            if(tdata_packet == expected_connection &&
               tdata_packet == expected_output &&
               tdata_packet == expected_crc) begin
                $display("[%0t] PACKET VALID: port=%0d vlan=%0d data=0x%0h",
                         $time, connection_addr.port_id, connection_addr.vlan_id, tdata_packet);
            end
            else begin
                $display("[%0t] PACKET INVALID: port=%0d vlan=%0d data=0x%0h | expected_connection=0x%0h expected_output=0x%0h expected_crc=0x%0h",
                         $time, connection_addr.port_id, connection_addr.vlan_id,
                         tdata_packet, expected_connection, expected_output, expected_crc);
            end
        end
    end
end

endtask 
endmodule
