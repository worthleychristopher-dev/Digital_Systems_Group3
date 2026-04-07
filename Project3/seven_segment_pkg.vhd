library ieee;
use ieee.std_logic_1164.all;

package seven_segment_pkg is

    -- 1. Record type for the 7 segments (a-g)
    type seven_segment_config is record
        a, b, c, d, e, f, g : std_logic;
    end record;

    -- Unconstrained array of records (for multi-digit displays)
    type seven_segment_config_vector is array (natural range <>) of seven_segment_config;

    -- 2. Enumerated type for lamp configuration
    type lamp_configuration is (common_anode, common_cathode);
    
    -- Constant for the DE10-Lite (Common Anode)
    constant default_lamp_config : lamp_configuration := common_anode;

    -- 3. The Hexadecimal Table (0-F)
    -- We define the "Active High" version here, then flip it in the function if needed
    type segment_table_t is array (0 to 15) of std_logic_vector(6 downto 0);
    
    -- Index:  g f e d c b a
    -- Bits:   6 5 4 3 2 1 0
    constant seven_segment_table : segment_table_t := (
        0 => "0111111", -- 0
        1 => "0000110", -- 1
        2 => "1011011", -- 2
        3 => "1001111", -- 3
        4 => "1100110", -- 4
        5 => "1101101", -- 5
        6 => "1111101", -- 6
        7 => "0000111", -- 7
        8 => "1111111", -- 8
        9 => "1101111", -- 9
        10 => "1110111", -- A
        11 => "1111100", -- b
        12 => "0111001", -- C
        13 => "1011110", -- d
        14 => "1111001", -- E
        15 => "1110001"  -- F
    );

    -- 4. Subtype and Function Prototypes
    subtype hex_digit is natural range 0 to 15;

    function get_hex_digit (
        digit: in hex_digit;
        lamp_mode: in lamp_configuration := default_lamp_config
    ) return seven_segment_config;

    function lamps_off (
        lamp_mode: in lamp_configuration := default_lamp_config
    ) return seven_segment_config;

end package seven_segment_pkg;

package body seven_segment_pkg is

    function get_hex_digit (
        digit: in hex_digit;
        lamp_mode: in lamp_configuration := default_lamp_config
    ) return seven_segment_config is
        variable bits : std_logic_vector(6 downto 0);
        variable result : seven_segment_config;
    begin
        bits := seven_segment_table(digit);
        
        -- If Common Anode (DE10-Lite), we must invert the bits 
        -- because '0' is ON.
        if lamp_mode = common_anode then
            bits := not bits;
        end if;

        result.a := bits(0);
        result.b := bits(1);
        result.c := bits(2);
        result.d := bits(3);
        result.e := bits(4);
        result.f := bits(5);
        result.g := bits(6);
        
        return result;
    end function;

    function lamps_off (
        lamp_mode: in lamp_configuration := default_lamp_config
    ) return seven_segment_config is
        variable result : seven_segment_config;
        variable off_val : std_logic;
    begin
        -- In Common Anode, '1' is OFF. In Common Cathode, '0' is OFF.
        if lamp_mode = common_anode then off_val := '1'; else off_val := '0'; end if;
        
        result.a := off_val; result.b := off_val; result.c := off_val;
        result.d := off_val; result.e := off_val; result.f := off_val;
        result.g := off_val;
        return result;
    end function;

end package body seven_segment_pkg;