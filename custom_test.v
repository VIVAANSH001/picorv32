module custom_test;
reg clk, resetn, mem_ready;// clk to synchronize , reset signal , memready to tell cpu you are ready
wire trap ,mem_valid, mem_instr; // the trap for illegal insts, memvalid to access memory, meminst to access inst
wire [31:0] mem_addr;// the address of memory trying to access
wire [31:0] mem_wdata;// wont be using
wire [3:0] mem_wstrb; // wont be using
reg [31:0] mem_rdata;// data you send to the CPU
reg [31:0] memory [0:255];// your own memory

picorv32 uut(.clk(clk) , .resetn(resetn) , .trap(trap) , .mem_valid(mem_valid) , .mem_instr(mem_instr) , .mem_ready(mem_ready) , .mem_addr(mem_addr) ,
.mem_wdata(mem_wdata) , .mem_wstrb(mem_wstrb) , .mem_rdata(mem_rdata));

initial begin
 memory[0] = 32'h00500593; //addi a1,x0,5
 memory[1] = 32'hFFD00613; //addi a2,x0,-3
 memory[2] = 32'h0005850B; //REV a0,a1
 memory[3] = 32'h0005950B; //ABS a0,a1
 memory[4] = 32'h00C5A50B; //MIN a0,a1,a2
 memory[5] = 32'h00C5B50B; //MAX a0,a1,a2
 memory[6] = 32'h00C5C50B; //SATADD a0,a1,a2
 memory[7] = 32'h00100073; //EBREAK
end

// The most important part the memory handshake.
always @(posedge clk)
begin
    mem_ready <= 0;
    if(mem_valid == 1 && mem_ready == 0)
    begin
        mem_ready <= 1;
        mem_rdata <= memory[mem_addr >> 2];
    end
end

//toggling of the clock
initial clk = 0;
always #5 clk = ~clk;

//reset CPU and values and only lets it start running after 20 ns as a safety net
initial begin
    resetn = 0;
    #20;
    resetn = 1;
end

//checking values being returned by functions
always @(posedge clk)
begin
    if(resetn &&uut.cpuregs_write && uut.latched_rd == 10)
    begin
        $display("a0 written: 0x%08X", uut.cpuregs_wrdata);
    end
end

// clean way to end simulation upon ebreak being applied
always @(posedge clk)
begin
    if(trap) 
    begin
        $finish;
    end
end


endmodule