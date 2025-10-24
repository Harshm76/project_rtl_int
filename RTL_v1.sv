

module axi_stream_queue_manager #(int DATA_SIZE = 32, int USER_SIZE = 16, int NUM_OF_INGRESS_PORTS = 3) (
     logic clk,
     logic rst_n,
     axi_str_inf.slave axis_in_inf[NUM_OF_INGRESS_PORTS];
     axi_str_inf.master axis_out_inf;
);
local parameter SRC_ADDR_WIDTH = 48 , DST_ADDR_WIDTH = 48;

//temp data queue 
logic [(DATA_SIZE-1):0] axis_pkt_temp_port_tdata_q[3][$][$];
logic [((DATA_SIZE/8)-1):0] axis_pkt_temp_port_tkeep_q[3][$][$];

//buffer data queue 
logic [(DATA_SIZE-1):0] axis_buffer_port_tdata_q[3][$:1024];
logic [((DATA_SIZE/8)-1):0] axis_buffer_port_tkeep_q[3][$:1024];
int buffer_q_size[3];
int total_drop_pkt_cnt[3]; //TODO per port or single

//arbiter output queue
logic [(DATA_SIZE-1):0] axis_arbiter_output_tdata_q[$];
logic [((DATA_SIZE/8)-1):0] axis_arbiter_output_tkeep_q[$];
logic axis_tuser_q[$];

//count of output packet from arbiter 
int axis_arbiter_output_count;

//count of packet drived by each port
int pkt_count_port[3];

connection_addr_t connection_addr;

always @(posedge clk) begin
  
  if(!rst_n) begin
    foreach(axis_pkt_temp_port_tdata_q[i]) axis_pkt_temp_port_tdata_q[i].delete();
    foreach(axis_pkt_temp_port_tkeep_q[i]) axis_pkt_temp_port_tkeep_q[i].delete();
    foreach(axis_buffer_port_tdata_q[i]) axis_buffer_port_tdata_q[i].delete();
    foreach(axis_buffer_port_tkeep_q[i]) axis_buffer_port_tkeep_q[i].delete();
    foreach(buffer_q_size[i]) buffer_q_size[i] = 0;
    foreach(pkt_count_port[i]) pkt_count_port[i] = 0;
    axis_arbiter_output_tdata_q.delete();
    axis_arbiter_output_tkeep_q.delete();
    axis_arbiter_output_count = 0;
  end
  
  else begin
    fork
      make_packet();
      buffer();
      arbiter();
    join_any
    drive_packet();
  end
end

//make packet
task make_packet();
  int j;
  foreach (axis_in_inf[i]) begin
    @(posedge clk iff axis_in_inf[i].tvalid);
    if(!axis_in_inf[i].tready) begin
       @(posedge clk iff axis_in_inf[i].tready);
    end
    axis_pkt_temp_port_tdata_q[i][j].push_back(axis_in_inf[i].tdata);
    axis_pkt_temp_port_tkeep_q[i][j].push_back(axis_in_inf[i].tkeep);
    if(axis_in_inf[i].tlast) begin
       axis_pkt_port_tdata_q[i][j].push_back(axis_in_inf[i].tdata);
       axis_pkt_port_tkeep_q[i][j].push_back(axis_in_inf[i].tkeep);
       @(posedge clk);
       j++;
    end
  end
endtask
 
  
//store in buffer 
//limited size 1024  
task buffer();
  foreach(axis_in_inf[i])begin
    wait(axis_pkt_temp_port_tdata_q[i].size() != 0);
    foreach(axis_pkt_temp_port_tdata_q[i][j]) begin
       if (axis_pkt_temp_port_tdata_q[i][j].size() + buffer_q_size[i] <= 1024) begin
          axis_buffer_port_tdata_q[i].push_back(axis_pkt_temp_port_tdata_q[i].pop_front());
	axis_buffer_port_tkeep_q[i].push_back(axis_pkt_temp_port_tkeep_q[i].pop_front());
          pkt_count_port[i]++;
          buffer_q_size[i] += axis_pkt_temp_port_tdata_q[i][j].size();
          axis_pkt_temp_port_tdata_q[i].delete();
       end
       else begin
          void(axis_pkt_temp_port_tdata_q[i].pop_front());
          $display("[%0t] WARNING: Buffer %0d is full, cannot move new packet!", $time, i);
       end
    end  
  end
endtask

//arbiter 

task arbiter();
  fork
    wait(axis_buffer_port_tdata_q[0].size() != 0);
    wait(axis_buffer_port_tdata_q[1].size() != 0);
    wait(axis_buffer_port_tdata_q[2].size() != 0);
  join_any
  disable fork;

  // Port 0 -> Arbiter Output
  while (axis_buffer_port_tdata_q[0].size() != 0) begin
    buffer_q_size[0] -= axis_buffer_port_tdata_q[0][0].size();
    connection_addr.vlan_id = {<<8{axis_buffer_port_tdata_q[0][0][((SRC_ADDR_WIDTH + DST_ADDR_WIDTH)/32)][12:0]}};
    connection_addr.port_id = 0;
    axis_tuser_q.push_back({connection_addr.vlan_id, connection_addr.port_id});
    axis_arbiter_output_tdata_q.push_back(axis_buffer_port_tdata_q[0].pop_front());
    axis_arbiter_output_tkeep_q.push_back(axis_buffer_port_tkeep_q[0].pop_front());
    axis_arbiter_output_count++;
  end
    
  // Port 1 -> Arbiter Output
  while (axis_buffer_port_tdata_q[1].size() != 0) begin
    buffer_q_size[1] -= axis_buffer_port_tdata_q[1][0].size();
    connection_addr.vlan_id = {<<8{axis_buffer_port_tdata_q[1][0][((SRC_ADDR_WIDTH + DST_ADDR_WIDTH)/32)][12:0]}};
    connection_addr.port_id = 1;
    axis_tuser_q.push_back({connection_addr.vlan_id, connection_addr.port_id});
    axis_arbiter_output_tdata_q.push_back(axis_buffer_port_tdata_q[1].pop_front());
    axis_arbiter_output_tkeep_q.push_back(axis_buffer_port_tkeep_q[1].pop_front());
    axis_arbiter_output_count++;
  end

  // Port 2 -> Arbiter Output
  while (axis_buffer_port_tdata_q[2].size() != 0) begin
    buffer_q_size[2] -= axis_buffer_port_tdata_q[2][0].size();
    connection_addr.vlan_id = {<<8{axis_buffer_port_tdata_q[2][0][((SRC_ADDR_WIDTH + DST_ADDR_WIDTH)/32)][12:0]}};
    connection_addr.port_id = 2;
    axis_tuser_q.push_back({connection_addr.vlan_id, connection_addr.port_id});
    axis_arbiter_output_tdata_q.push_back(axis_buffer_port_tdata_q[2].pop_front());
    axis_arbiter_output_tkeep_q.push_back(axis_buffer_port_tkeep_q[2].pop_front());
    axis_arbiter_output_count++;
  end

endtask

task drive_packet();
 logic [(DATA_SIZE-1):0] axis_tdata_q[$];
 logic [((DATA_SIZE/8)-1):0] axis_tkeep_q[$];  
 wait(axis_arbiter_output_tdata_q.size() != 0);
  
 //make packet 
 foreach(axis_arbiter_output_tdata_q[0][i]) begin
   axis_tdata_q.push_back(axis_arbiter_output_tdata_q[0][i]);
   axis_tkeep_q.push_back(axis_arbiter_output_tkeep_q[0][i]);
 end
 //delete from axis_arbiter_output_tdata_q
 void(axis_arbiter_output_tdata_q.pop_front());
 void(axis_arbiter_output_tkeep_q.pop_front());
 axis_out_inf.tvalid = 1'b1;
 for(int i=0;i<axis_tdata_q.size();i++) begin
   axis_out_inf.tuser = axis_tuser_q.pop_front();
   axis_out_inf.tdata = axis_tdata_q.pop_front();
   axis_out_inf.tkeep = axis_tkeep_q.pop_front();
   axis_out_inf.tlast = 1'b0;
   if(i = axis_tdata_q.size()-1) begin
        axis_out_inf.tlast = 1'b1;
        @(posedge clk);
   end
   @(posedge clk iff axis_out_inf.tready);
   axis_out_inf.tvalid = 1'b0;
end
  
endtask

endmodule
