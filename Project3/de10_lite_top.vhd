library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.seven_segment_pkg.all;

library altera;
use altera.altera_primitives_components.all;

entity de10_lite_top is
    port (
        MAX10_CLK1_50   : in    std_logic;
        ADC_CLK_10      : in    std_logic;
        HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : out std_logic_vector(6 downto 0);
        KEY             : in    std_logic_vector(1 downto 0);
        SW              : in    std_logic_vector(9 downto 0);
        LEDR            : out   std_logic_vector(9 downto 0)
    );
end entity de10_lite_top;

architecture top_arch of de10_lite_top is
    -- 1. SIGNAL DECLARATIONS
    signal clk_10MHz_pll : std_logic;
    signal clk_1MHz_raw  : std_logic;
    signal clk_1MHz      : std_logic;
    signal pll_locked    : std_logic;
    
    signal adc_soc       : std_logic := '0';
    signal adc_eoc       : std_logic; -- Linked to Sample Store IRQ
    signal adc_dout_32   : std_logic_vector(31 downto 0);
    signal adc_dout      : natural range 0 to 4095;
    
    signal display_data  : std_logic_vector(11 downto 0) := (others => '0');
    signal inclk_vector  : std_logic_vector(3 downto 0) := (others => '0');
    
    -- CDC Synchronizers
    signal eoc_latch     : std_logic := '0';
    signal soc_sync1     : std_logic := '0';
    signal soc_sync2     : std_logic := '0';

    type state_t is (IDLE, START_CONV, WAIT_FOR_EOC, CAPTURE);
    signal state         : state_t := IDLE;
    signal sample_timer  : unsigned(20 downto 0) := (others => '0');
    signal capture_timer : unsigned(7 downto 0)  := (others => '0');
    signal hex0_rec, hex1_rec, hex2_rec : seven_segment_config;

    component altclkctrl
        port (
            inclk  : in  std_logic_vector(3 downto 0);
            outclk : out std_logic
        );
    end component;

begin

    -- 2. CLOCK CONTROL & PLL
    inclk_vector <= "000" & clk_1MHz_raw;

    global_inst : altclkctrl
        port map (
            inclk  => inclk_vector,
            outclk => clk_1MHz
        );

    U_PLL : entity work.adc_pll
        port map (
            areset => '1',
            inclk0 => ADC_CLK_10,
            c0     => clk_10MHz_pll, -- 10MHz for ADC
            c1     => clk_1MHz_raw,  -- 1MHz for Logic
            locked => pll_locked
        );

    -- 3. MODULAR ADC INSTANTIATION (Aligned with your IP Ports)
    U_ADC : entity work.modular_adc
        port map (
            clock_clk                  => clk_1MHz,
            adc_pll_clock_clk          => clk_10MHz_pll,
            adc_pll_locked_export      => pll_locked,
            reset_sink_reset_n         => pll_locked,
            
            -- Command: Force read from Channel 17 (Temperature Sensor)
            sample_store_csr_address   => "0000001", -- Hex 11 / Dec 17
            sample_store_csr_read      => '1', 
            sample_store_csr_write     => '0',
            sample_store_csr_writedata => (others => '0'),
            sample_store_csr_readdata  => adc_dout_32,
            
            -- Sequencer: Keep it triggered
            sequencer_csr_address      => '0',
            sequencer_csr_read         => '0',
            sequencer_csr_write        => '1',
            sequencer_csr_writedata    => x"00000001", -- Start bit
            sequencer_csr_readdata     => open,
            
            sample_store_irq_irq       => adc_eoc
        );

    adc_dout <= to_integer(unsigned(adc_dout_32(11 downto 0)));

    ---------------------------------------------------------
    -- 10 MHz process: CDC Handshake
    ---------------------------------------------------------
    process(clk_10MHz_pll)
    begin
        if rising_edge(clk_10MHz_pll) then
            soc_sync1 <= adc_soc;
            soc_sync2 <= soc_sync1;
            
            if adc_eoc = '1' then
                eoc_latch <= '1';
            elsif soc_sync2 = '1' then
                eoc_latch <= '0';
            end if;
        end if;
    end process;

    ---------------------------------------------------------
    -- 1 MHz process: Main FSM
    ---------------------------------------------------------
    process(clk_1MHz)
        variable temp_bin : unsigned(11 downto 0);
        variable bcd      : unsigned(15 downto 0);
    begin
        if rising_edge(clk_1MHz) then
            if pll_locked = '0' then
                state        <= IDLE;
                sample_timer <= (others => '0');
                adc_soc      <= '0';
            else
                case state is
                    when IDLE =>
                        adc_soc <= '0';
                        if sample_timer >= 1_000_000 then -- Approx 10Hz
                            sample_timer <= (others => '0');
                            state <= START_CONV;
                        else
                            sample_timer <= sample_timer + 1;
                        end if;

                    when START_CONV =>
                        adc_soc <= '1';
                        state   <= WAIT_FOR_EOC;

                    when WAIT_FOR_EOC =>
                        adc_soc <= '0';
                        if eoc_latch = '1' then
                            capture_timer <= (others => '0');
                            state <= CAPTURE;
                        end if;

                    when CAPTURE =>
                        capture_timer <= capture_timer + 1;
                        if capture_timer >= 10 then
                            display_data <= std_logic_vector(to_unsigned(adc_dout, 12));
                            state <= IDLE;
                        end if;

                    when others => state <= IDLE;
                end case;
            end if;

            -- 4. DISPLAY DECODING (Active-Low Inversion below)
            hex0_rec <= get_hex_digit(to_integer(unsigned(display_data(3 downto 0))));
            hex1_rec <= get_hex_digit(to_integer(unsigned(display_data(7 downto 4))));
            hex2_rec <= get_hex_digit(to_integer(unsigned(display_data(11 downto 8))));
        end if;
    end process;

    -- 5. HARDWARE MAPPING (Note the 'NOT' for Active-Low displays)
    HEX0 <= not (hex0_rec.g & hex0_rec.f & hex0_rec.e & hex0_rec.d & hex0_rec.c & hex0_rec.b & hex0_rec.a);
    HEX1 <= not (hex1_rec.g & hex1_rec.f & hex1_rec.e & hex1_rec.d & hex1_rec.c & hex1_rec.b & hex1_rec.a);
    HEX2 <= not (hex2_rec.g & hex2_rec.f & hex2_rec.e & hex2_rec.d & hex2_rec.c & hex2_rec.b & hex2_rec.a);
    
    HEX3 <= (others => '1'); HEX4 <= (others => '1'); HEX5 <= (others => '1');

    LEDR(9 downto 3) <= adc_dout_32(11 downto 5);
	 LEDR(2) <= adc_eoc;
	 LEDR(1 downto 0) <= adc_dout_32(4 downto 3);

end architecture;