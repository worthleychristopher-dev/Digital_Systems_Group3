library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wysiwyg;
use wysiwyg.fiftyfivenm_components.all;

entity max10_adc is
    port (
        pll_clk:    in  std_logic;
        chsel:      in  natural range 0 to 31;
        soc:        in  std_logic;
        tsen:       in  std_logic;
        dout:       out natural range 0 to 4095;
        eoc:        out std_logic;
        clk_dft:    out std_logic
    );
end entity max10_adc;

architecture wrapper of max10_adc is
    signal adc_dout: std_logic_vector(11 downto 0);
    signal adc_chsel: std_logic_vector(4 downto 0);
begin
    dout <= to_integer(unsigned(adc_dout));
    adc_chsel <= std_logic_vector(to_unsigned(chsel, 5));

    primitive_instance: fiftyfivenm_adcblock
        generic map (
            clkdiv => 2, 
				tsclkdiv => 1, 
				tsclksel => 0, 
				pwd => 0, 
				prescalar => 0, 
            refsel => 1, 
				device_partname_fivechar_prefix => "10M50", 
            is_this_first_or_second_adc => 1, 
				analog_input_pin_mask => 0, 
            enable_usr_sim => 0, 
				reference_voltage_sim => 0
        )
        port map (
            chsel => adc_chsel, soc => soc, eoc => eoc, usr_pwd => '0', 
            tsen => tsen, clk_dft => clk_dft, dout => adc_dout, 
            clkin_from_pll_c0 => pll_clk
        );
end architecture wrapper;
