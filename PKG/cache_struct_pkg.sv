`include "defines.sv"

package cache_struct_pkg;

    //Counter variables
    real cache_read_cnt;
    real cache_write_cnt;
    real cache_hit_cnt;
    real cache_miss_cnt;
    real cache_hit_ratio;

    //PLRU bit-array declaration (Dynamic array)
    bit [`PLRU_BITS-1:0] update_plru_temp;
    int update_plru_index = 0;
    int victim_plru_index = 0;
    int plru_bit_shift = 0;
    string mode;
    int verbosity_in;
    bit debug_mode_pkg = 0;
    int way_out;
    bit clk;


    //Enum declaration for MESI Protocol States
    typedef enum bit [1:0] {INVALID = 2'b00,
                            SHARED = 2'b01,
                            EXCLUSIVE = 2'b10,
                            MODIFIED = 2'b11} mesi_states_e;

    //Variable declaration
    mesi_states_e mesi_state_temp;
    

    //One-cache line contains: Valid bit, Dirty bit, Tag bit, MESI State
    //Let's declare user-defined structure for one cache line
    typedef struct {mesi_states_e mesi_state;
                    logic [`TAG_BITS-1:0] tag;} cache_line_st;

    //One-set contains: (16-1)=15 PLRU bits, 16 cache-lines 
    typedef struct {logic [`PLRU_BITS-1:0] plru_bits;
                    cache_line_st cache_line [`NUM_OF_WAYS_OF_ASSOCIATIVITY-1:0];} cache_set_st [`NUM_OF_SETS];

    //Declare cache memory
    cache_set_st cache_mem;

    //Snoop Result Enumeration
    typedef enum logic [1:0] {HIT = 2'b00,
                              HITM = 2'b01,
                              NOHIT = 2'b10} snoop_result_e;

    //Snoop result variable
    snoop_result_e snoop_result;

    //Enum declaration for Bus Operation Posibilities
    typedef enum logic [1:0] {READ = 2'b00,
                              WRITE = 2'b01,
                              INVALIDATE = 2'b10,
                              RWIM = 2'b11} bus_op_e;
    
    //Bus operation variable
    bus_op_e bus_op;
    
    /*
    GETLINE = If L2 detects that a line is modified in L1 (based on coherence states) and L2 needs the updated data
    (e.g., because the line is being evicted or shared), it sends a GETLINE message to L1. This ensures that L2 gets the latest,
    modified copy of the data from L1.

    SENDLINE = When L1 requests a line from L2 (e.g., due to an L1 cache miss), L2 sends the requested line using a SENDLINE message.

    INVALIDATELINE = When L2 determines that a line in L1 is no longer valid (e.g., due to coherence protocol requirements or an eviction),
    it sends an INVALIDATELINE message to L1 to remove the line or mark it invalid.

    EVICTLINE = When L2 evicts a line as part of its replacement policy, it must ensure consistency. If the line is present in L1,
    L2 must either retrieve the latest data (via GETLINE) or invalidate it (via INVALIDATELINE).
    */

    //Enum declaration for message to cache
    typedef enum logic [1:0] {GETLINE = 2'b00,
                              SENDLINE = 2'b01,
                              INVALIDATELINE = 2'b10,
                              EVICTLINE = 2'b11} message_to_L1_cache_e;
    
    //Message to cache variable
    message_to_L1_cache_e msg_to_cache;

    //Verbosity Levels for display priority
    typedef enum int { NONE = 0,        //NO output
                       LOW = 1,         //LOW level display
                       MED = 2,         //MED level display
                       HIGH = 3,        //HIGH level display
                       FULL = 4,        //FULL level display
                       DEBUG = 5        //DEBUG level display
                       } verbosity_t;
                
    //Global verbosity level (can be set dynamically)
    verbosity_t verbosity_level;
                
    //Function: Verbosity-controlled display task
    function void display_val(verbosity_t level, string msg);
        if(debug_mode_pkg == 1)
        begin
            if (level <= verbosity_level) begin
                case (level)
                    NONE    :   $display("%s", msg);
                    LOW     :   $display("%s", msg);
                    MED     :   $display("%s", msg);
                    HIGH    :   $display("%s", msg);
                    FULL    :   $display("%s", msg);
                    DEBUG   :   $display("%s", msg);
                    default :   $display("[UNKNOWN] %s", msg);
                endcase
            end
        end
    endfunction

    //Function: Initialize cache memory
    function void initialize_cache_mem();
        //Counter variables
        cache_read_cnt = 0;
        cache_write_cnt = 0;
        cache_hit_cnt = 0;
        cache_miss_cnt = 0;
        cache_hit_ratio = 0;
        for (int i = 0; i < `NUM_OF_SETS; i++)
        begin
            for (int j = 0; j < `NUM_OF_WAYS_OF_ASSOCIATIVITY; j++)
            begin
                cache_mem[i].cache_line[j].tag = 'hx;
                cache_mem[i].cache_line[j].mesi_state = INVALID;
                cache_mem[i].plru_bits[j] = 'b0;  					// Setting PLRU to 00000000 while initializing
            end
        end
    endfunction
                
    //Function: Prints the contents of each valid cache line.
    function void print_cache_mem(input cache_set_st cache_mem);
        $display("\n-----------------------------------------------------------------------------------");	
        $display("                CACHE_MEM [SET] [WAY] [PLRU Bits]= [TAG] [MESI STATE]              ");	
        $display("-----------------------------------------------------------------------------------");
        for (int i = 0; i < `NUM_OF_SETS; i++)
        begin
            for (int j = 0; j < `NUM_OF_WAYS_OF_ASSOCIATIVITY; j++)
            begin
                if(cache_mem[i].cache_line[j].mesi_state != INVALID)				
                    $display("CACHE_MEM [%0d][%0d]\t[%b] = [%0h] \t[%0s]", i, j, cache_mem[i].plru_bits, cache_mem[i].cache_line[j].tag, cache_mem[i].cache_line[j].mesi_state.name);
            end
        end
    endfunction
    
    //Function: Display summary of counts
    function void display_summary();
        if(cache_read_cnt + cache_write_cnt != 0.0000)
            cache_hit_ratio = (cache_hit_cnt)/(cache_read_cnt + cache_write_cnt);
        $display("\n-----------------------------------------------------------------------------------");	
        $display("                                     SUMMARY                                       ");	
        $display("-----------------------------------------------------------------------------------");	
        $display("NUMBER OF CACHE READS\t\t = %0d", int'(cache_read_cnt));	
        $display("NUMBER OF CACHE WRITES\t = %0d", int'(cache_write_cnt));	
        $display("NUMBER OF CACHE HITS\t\t = %0d", int'(cache_hit_cnt));	
        $display("NUMBER OF CACHE MISSES\t = %0d", int'(cache_miss_cnt));	
        $display("CACHE HIT RATIO\t\t = %0f", cache_hit_ratio);	
        $display("CACHE HIT RATIO PERCENTAGE\t = %0.2f %%", cache_hit_ratio*100);	
        $display("-----------------------------------------------------------------------------------");	
    endfunction

    //Function: PLRU Update logic
    function void update_plru(int w);

        update_plru_index = 0;

        for(int binary_bit_level = ($clog2(`NUM_OF_WAYS_OF_ASSOCIATIVITY)-1); binary_bit_level >= 0; binary_bit_level--)
        begin
            plru_bit_shift = (w >> binary_bit_level) & 1;          //Extract last bit of given way
            update_plru_temp[update_plru_index] = plru_bit_shift;
            if(binary_bit_level > 0)
            begin
                update_plru_index = (2*update_plru_index) + 1 + plru_bit_shift;
            end
        end

        display_val(DEBUG, "\nUpdated_PLRU:");
        foreach(update_plru_temp[i])
        begin
            if(mode == "NORMAL" && verbosity_in > 2)
                $write("[%0d]=%b, ", i, update_plru_temp[i]);
        end
        if(mode == "NORMAL")
            display_val(MED, $sformatf("PLRU = %b\n", update_plru_temp));

    endfunction: update_plru

    //Function: Eviction logic after the set becomes full
    function void victim_plru(bit [`PLRU_BITS-1:0] PLRU);
        begin
            victim_plru_index = 0;
            way_out = 0;
            PLRU[0] = ~PLRU[0];  // XOR PLRU[0] with 1
            
            for(int binary_bit_level = ($clog2(`NUM_OF_WAYS_OF_ASSOCIATIVITY)-1); binary_bit_level >= 0; binary_bit_level--)
            begin
                if (PLRU[victim_plru_index] == 0)               // Left child access
                begin
                    victim_plru_index = 2 * victim_plru_index + 1;          // Update index for left child
                    PLRU[victim_plru_index] = ~PLRU[victim_plru_index];
                    way_out = 2*way_out;  
                end
                else if (PLRU[victim_plru_index] == 1)  // Right child access
                begin
                    victim_plru_index = 2 * victim_plru_index + 2;  // Update index for right child
                    PLRU[victim_plru_index] = ~PLRU[victim_plru_index];  // XOR with 1 (toggle the value)
                    way_out = (2*way_out)+1;
                end
            end
            update_plru_temp = PLRU;
            display_val(MED, $sformatf("Targeted Eviction at WAY = %0d", way_out));
            display_val(DEBUG, "\nUpdated_PLRU:");
            foreach(update_plru_temp[i])
            begin
                if(mode == "NORMAL" && verbosity_in > 2)
                    $write("[%0d]=%b, ", i, update_plru_temp[i]);
            end
            if(mode == "NORMAL")
                display_val(MED, $sformatf("PLRU = %b\n", update_plru_temp));
        end
    endfunction

    //Function: Getting snoop result value from other processor (HIT, NOHIT, HITM)
    function void get_snoop_result(input bit [`PHYSICAL_ADDR_BITS-1:0] physical_addr, output snoop_result_e snoop_result);
        if(physical_addr[1:0] == 2'b00)
        begin
            snoop_result = HIT;
        end
        if(physical_addr[1:0] == 2'b01)
        begin
            snoop_result = HITM;
        end
        if(physical_addr[1:0] == 2'b10 || physical_addr[1:0] == 2'b11)
        begin
            snoop_result = NOHIT;
        end
    endfunction: get_snoop_result
    
    //Function: Putting snoop result value to other processor (HIT, NOHIT, HITM)
    function void put_snoop_result(input bit [`PHYSICAL_ADDR_BITS-1:0] physical_addr, input snoop_result_e snoop_result);
        if(mode == "NORMAL")
            display_val(MED, $sformatf("Snoop Result: Address = %h, Snoop Result = %s", physical_addr, snoop_result));
    endfunction: put_snoop_result
    
    //Function: Bus operation function
    function void bus_operation(input bus_op_e bus_op, input logic [`PHYSICAL_ADDR_BITS-1:0] physical_addr);
        get_snoop_result(physical_addr, snoop_result);
        if(mode == "NORMAL")
            display_val(MED, $sformatf("Bus Operation: %s, Address = %h, Snoop Result = %s", bus_op, physical_addr, snoop_result));
    endfunction: bus_operation
    
    //Function: Used for communication with upper level cache
    function void message_to_L1_cache(message_to_L1_cache_e msg_to_cache, logic [`PHYSICAL_ADDR_BITS-1:0] physical_addr);
        if(mode == "NORMAL")
            display_val(MED, $sformatf("Message: L2 to L1 -> %s, Address = %h", msg_to_cache.name, physical_addr));
    endfunction: message_to_L1_cache
    
endpackage: cache_struct_pkg