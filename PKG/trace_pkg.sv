`include "defines.sv"

package trace_pkg;

    import cache_struct_pkg::*;

    //Trace file input value variable
    logic [`TRACE_CMD_LEN-1:0] cmd;
    logic [`PHYSICAL_ADDR_BITS-1:0] address;
    string cmd_description = "";

    //Cache calculation variables
    bit [`PHYSICAL_ADDR_BITS-1:0] physical_addr;
    bit [`BYTE_OFFSET_BITS-1:0] byte_offset;
    bit [`NUM_OF_SETS_BITS-1:0] set_val;
    bit [`TAG_BITS-1:0] tag_val;

    function void display_given_data();
        $display("---------------------- SUMMARY OF GIVEN/CALCULATED DATA ----------------------");
        $display("CACHE_CAPACITY                : %h (Hex), %0d (Dec)", `CACHE_CAPACITY, `CACHE_CAPACITY);
        $display("PHYSICAL_ADDR_BITS            : %h (Hex), %0d (Dec)", `PHYSICAL_ADDR_BITS, `PHYSICAL_ADDR_BITS);
        $display("BYTE_OFFSET                   : %h (Hex), %0d (Dec)", `BYTE_OFFSET, `BYTE_OFFSET);
        $display("BYTE_OFFSET_BITS              : %h (Hex), %0d (Dec)", `BYTE_OFFSET_BITS, `BYTE_OFFSET_BITS);
        $display("NUM_OF_WAYS_OF_ASSOCIATIVITY  : %h (Hex), %0d (Dec)", `NUM_OF_WAYS_OF_ASSOCIATIVITY, `NUM_OF_WAYS_OF_ASSOCIATIVITY);
        $display("NUM_OF_CACHE_LINES            : %h (Hex), %0d (Dec)", `NUM_OF_CACHE_LINES, `NUM_OF_CACHE_LINES);
        $display("NUM_OF_SETS                   : %h (Hex), %0d (Dec)", `NUM_OF_SETS, `NUM_OF_SETS);
        $display("NUM_OF_CACHE_LINES_PER_SET    : %h (Hex), %0d (Dec)", `NUM_OF_CACHE_LINES_PER_SET, `NUM_OF_CACHE_LINES_PER_SET);
        $display("NUM_OF_SETS_BITS              : %h (Hex), %0d (Dec)", `NUM_OF_SETS_BITS, `NUM_OF_SETS_BITS);
        $display("TAG_BITS                      : %h (Hex), %0d (Dec)", `TAG_BITS, `TAG_BITS);
        $display("PLRU_BITS                     : %h (Hex), %0d (Dec)", `PLRU_BITS, `PLRU_BITS);
        $display("-----------------------------------------------------------------------------");
    endfunction

    function string assign_cmd_description (bit [`TRACE_CMD_LEN-1:0] cmd_val);
        case(cmd_val)
            0   :   return "read request from L1 data cache";
            1   :   return "write request from L1 data cache";
            2   :   return "read request from L1 instruction cache";
            3   :   return "snooped read request";
            4   :   return "snooped write request";
            5   :   return "snooped read with intent to modify request";
            6   :   return "snooped invalidate command";
            8   :   return "clear the cache and reset all state";
            9   :   return "print contents and state of each valid cache line (does not end simulation!)";
        endcase
    endfunction: assign_cmd_description

    function void address_slicing (bit [`PHYSICAL_ADDR_BITS-1:0] physical_addr);
        physical_addr = physical_addr;
        get_snoop_result(physical_addr, snoop_result);
        {tag_val, set_val, byte_offset} = physical_addr;
        display_val(FULL, $sformatf("physical_address = %h (Hex) , %b (Bin)", physical_addr, physical_addr));
        display_val(FULL, $sformatf("byte_offset = %0d (Dec) , %b (Bin)", byte_offset, byte_offset));
        display_val(FULL, $sformatf("set_val = %0d (Dec) , %b (Bin)", set_val, set_val));
        display_val(FULL, $sformatf("tag_val = %0d (Dec) , %b (Bin)", tag_val, tag_val));
        display_val(FULL, "-----------------------------------------------------------------------------------");
    endfunction: address_slicing

endpackage: trace_pkg