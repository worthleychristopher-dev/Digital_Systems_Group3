library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.vga_data.all;
use work.color_data.all;

entity toplevel is
    port(
        CLOCK_50 : in std_logic;
        RESET    : in std_logic;

        VGA_HS   : out std_logic;
        VGA_VS   : out std_logic;

        VGA_R    : out std_logic_vector(3 downto 0);
        VGA_G    : out std_logic_vector(3 downto 0);
        VGA_B    : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of toplevel is

    signal point_sig       : coordinate;
    signal point_valid_sig : boolean;

    signal stage_data      : color_index_type := 0;
    signal manager_ready   : std_logic := '1';

    signal palette_sig     : color_table_type;
    signal color_sig       : rgb_color;

begin

    VGA_CORE : entity work.vga_fsm
        port map(
            vga_clock   => CLOCK_50,
            reset       => RESET,
            point       => point_sig,
            point_valid => point_valid_sig,
            h_sync      => VGA_HS,
            v_sync      => VGA_VS
        );

    palette_sig <= get_palette(0);

    process(point_sig, point_valid_sig)
    begin
        if point_valid_sig then
            if point_sig.x < 160 then
                stage_data <= 0;
            elsif point_sig.x < 320 then
                stage_data <= 1;
            elsif point_sig.x < 480 then
                stage_data <= 2;
            else
                stage_data <= 3;
            end if;
        else
            stage_data <= 0;
        end if;
    end process;

    color_sig <= get_color(stage_data, palette_sig) when manager_ready = '1'
                 else color_black;

    VGA_R <= std_logic_vector(to_unsigned(color_sig.red, 4));
    VGA_G <= std_logic_vector(to_unsigned(color_sig.green, 4));
    VGA_B <= std_logic_vector(to_unsigned(color_sig.blue, 4));

end architecture;