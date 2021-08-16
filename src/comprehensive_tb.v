`timescale 1ns / 1ps

module comprehensive_tb(
	input clk,rst_n,
	input[2:0] key, //key[0] for burst writing, key[1] for burst reading , press key[2] along with key[0] to inject 10240 errors to be displayed on the seven-segment LEDs
	output[3:0] led, //led[1:0] will light up if burst writing is successfull, led[3:0] will light up if burst reading is successful
	output [7:0] seg_out,
	output [5:0] sel_out,
	//FPGA to SDRAM
	output sdram_clk,
	output sdram_cke, 
	output sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n, 
	output[12:0] sdram_addr,
	output[1:0] sdram_ba, 
	output[1:0] sdram_dqm, 
	inout[15:0] sdram_dq
    );
	 
	 //FSM state declarationss
	 localparam idle=0,
					//write test-data to all addresses
					new_write=1,
					write_burst=2,
					//read test-data written to all addresses
					new_read=3,
					read_burst=4;
					
	 reg[2:0] state_q=idle,state_d;
	 reg[14:0] f_addr_q=0,f_addr_d; 
	 reg[9:0] burst_index_q=0,burst_index_d;
	 reg[3:0] led_q=0,led_d;
	 reg[19:0] error_q=0,error_d;
	 
	 reg rw,rw_en;
	 reg[15:0] f2s_data;
	 wire ready,s2f_data_valid,f2s_data_valid;
	 wire[15:0] s2f_data;
	 wire key0_tick,key1_tick;
	 wire[5:0] in0,in1,in2,in3,in4,in5; //format: {dp,char[4:0]} , dp is active high
	 
	 (*KEEP="TRUE"*)reg[36:0] counter_q,index_q,index_d; //counter_q increments until 1 second(165_000_000 clk cycles). Index_q holds the number of words read/written(check the value at chipscope)	
								//Memory Bandwidth: index_q*2 = X bytes/seconds
								// RESULT: 190MB/s (100MHz with t_CL=2)
								// RESULT: 316MB/s (165MHz clk with t_CL=3)
	 
	 //register operations
	 always @(posedge CLK_OUT,negedge rst_n) begin
		if(!rst_n) begin
			state_q<=0;
			f_addr_q<=0;
			burst_index_q<=0;
			led_q<=0;
			error_q<=0;
			counter_q<=0;
			index_q<=0;
		end
		else begin
			state_q<=state_d;
			f_addr_q<=f_addr_d;
			burst_index_q<=burst_index_d;
			led_q<=led_d;
			error_q<=error_d;	
			counter_q<=(state_q==idle) ?0:counter_q+1'b1;
			index_q<=index_d;
		end
	 end
	 
	 //FSM next-state logic
	 always @* begin
	 state_d=state_q;
 	 f_addr_d=f_addr_q;
	 burst_index_d=burst_index_q;
	 led_d=led_q;
	 error_d=error_q;
	 rw=0;
	 rw_en=0;
	 f2s_data=0;
	 index_d=index_q;
	 
	 case(state_q)		
		  		 idle: begin  //wait until either button is toggled
							f_addr_d=0;
							burst_index_d=0;
							if(key0_tick) begin
								state_d=new_write; 
								index_d=0;
							end
							if(key1_tick) begin
								state_d=new_read;
								error_d=0;
								index_d=0;
							end
						 end
		  new_write: if(ready) begin  //write a deterministic data to all possible addresses of sdram
							led_d[1]=1'b1;
							rw_en=1;
							rw=0;
							state_d=write_burst;
							burst_index_d=0;
						 end
		write_burst: begin 
							f2s_data=f_addr_q+burst_index_q;
							if(!key[2] && (f_addr_q==13000 || f_addr_q==100)) f2s_data=9999; //Inject errors when key[2] is pressed. The output error must be 512*2*10=10240
							if(f2s_data_valid) begin
								burst_index_d=burst_index_q+1; //track the number of already bursted data
								index_d=index_q+1'b1; //holds the total number of words written to sdram
							end
							else if(burst_index_q==512) begin //last data must be 512th(for full page mode), since index starts at zero, the 512th is expected to have deasserted f2s_data_valid
								if(counter_q>=165_000_000) begin //1 second had passed
									led_d[1:0]=2'b11; 
									state_d=idle;
								end
								else begin
									f_addr_d=f_addr_q+1;
									state_d=new_write;
								end
							end
						 end
		   new_read: if(ready) begin //read each data from all addresses and test if it matches the deterministic data we assigned earlier
							led_d[2]=1'b1;
							rw_en=1;
							rw=1;
							state_d=read_burst;
							burst_index_d=0;
						 end
		 read_burst: begin
							if(s2f_data_valid) begin
								if(s2f_data!=f_addr_q+burst_index_q) error_d=error_q+1'b1; //count the errors in which the read output does not match the expected assigned data
								burst_index_d=burst_index_q+1;
								index_d=index_q+1'b1; //holds the total number of words read from sdram
							end
							else if(burst_index_q==512) begin
								if(counter_q>=165_000_000) begin //1 second had passed
									led_d[3:0]=4'b1111; //all leds on after successfull write
									state_d=idle;
								end
								else begin
									f_addr_d=f_addr_q+1;
									state_d=new_read;
								end
							end
						 end
		    default: state_d=idle;
	 endcase
	 end
	 
	 assign led=led_q;
	
	//module instantiations
	 sdram_controller m0
	 (
		//fpga to controller
		.clk(CLK_OUT), //clk=100MHz
		.rst_n(rst_n),  
		.rw(rw), // 1:read , 0:write
		.rw_en(rw_en), //must be asserted before read/write
		.f_addr(f_addr_q), //23:11=row  , 10:9=bank  , no need for column address since full page mode will always start from zero and end with 511 words
		.f2s_data(f2s_data), //fpga-to-sdram data
		.s2f_data(s2f_data), //sdram to fpga data
		.s2f_data_valid(s2f_data_valid),  //asserts while  burst-reading(data is available at output UNTIL the next rising edge)
		.f2s_data_valid(f2s_data_valid), //asserts while burst-writing(data must be available at input BEFORE the next rising edge)
		.ready(ready), //"1" if sdram is available for nxt read/write operation
		//controller to sdram
		.s_clk(sdram_clk),
		.s_cke(sdram_cke), 
		.s_cs_n(sdram_cs_n),
		.s_ras_n(sdram_ras_n ), 
		.s_cas_n(sdram_cas_n),
		.s_we_n(sdram_we_n), 
		.s_addr(sdram_addr), 
		.s_ba(sdram_ba), 
		.LDQM(sdram_dqm[0]),
		.HDQM(sdram_dqm[1]),
		.s_dq(sdram_dq) 
    );
	 
	 debounce_explicit m1
	(
		.clk(CLK_OUT),
		.rst_n(rst_n),
		.sw({!{key[0]}}),
		.db_level(),
		.db_tick(key0_tick)
    );
	 
	  debounce_explicit m2
	(
		.clk(CLK_OUT),
		.rst_n(rst_n),
		.sw({!{key[1]}}),
		.db_level(),
		.db_tick(key1_tick)
    );
	 
	 LED_mux m3
	(
		.clk(CLK_OUT),
		.rst(rst_n),
		.in0(in0),
		.in1(in1),
		.in2(in2),
		.in3(in3),
		.in4(in4),
		.in5(in5), //format: {dp,char[4:0]} , dp is active high
		.seg_out(seg_out),
		.sel_out(sel_out)
    );
	 
	 bin2bcd m4
	 (
	.clk(CLK_OUT),
	.rst_n(rst_n),
	.start(1),
	.bin(error_q),//11 digit max of {11{9}}
	.ready(),
	.done_tick(),
	.dig0(in0),
	.dig1(in1),
	.dig2(in2),
	.dig3(in3),
	.dig4(in4),
	.dig5(in5),
	.dig6(),
	.dig7(),
	.dig8(),
	.dig9(),
	.dig10() //not all output will be used(this module is a general-purpose bin2bcd)
    );
	 
	 //100MHz clock
	 dcm_165MHz m5
   (
		 .clk(clk), // IN
		 // Clock out ports
		 .CLK_OUT(CLK_OUT),     // OUT
		 // Status and control signals
		 .RESET(RESET),// IN
		 .LOCKED(LOCKED)
	 );      // OUT

endmodule
