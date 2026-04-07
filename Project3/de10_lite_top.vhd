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

    -- Clock signals
    signal clk_10MHz_pll : std_logic;
    signal clk_1MHz_raw  : std_logic;
    signal pll_locked    : std_logic;

    -- ADC signals
    signal adc_eoc       : std_logic;
    signal adc_dout_32   : std_logic_vector(31 downto 0);
    signal adc_dout      : natural range 0 to 4095;

    -- CDC signals
    signal eoc_latch     : std_logic := '0';
    signal eoc_sync1     : std_logic := '0';
    signal eoc_sync2     : std_logic := '0';

    -- Display signals
    signal display_data  : std_logic_vector(11 downto 0) := (others => '0');
    signal hex0_rec, hex1_rec, hex2_rec : seven_segment_config;

    -- FSM
    type state_t is (WAIT_FOR_IRQ, CAPTURE);
    signal state          : state_t := WAIT_FOR_IRQ;
    signal capture_timer  : unsigned(7 downto 0)  := (others => '0');
    signal sample_counter : unsigned(19 downto 0) := (others => '0');

    -- Sequencer init signals
    signal seq_init_done : std_logic := '0';
    signal seq_write     : std_logic := '0';
    signal seq_writedata : std_logic_vector(31 downto 0) := (others => '0');

begin

    U_PLL : entity work.adc_pll
        port map (
            areset => '0',
            inclk0 => ADC_CLK_10,
            c0     => clk_10MHz_pll,
            c1     => clk_1MHz_raw,
            locked => pll_locked
        );

    U_ADC : entity work.modular_adc
        port map (
            clock_clk                  => clk_10MHz_pll,
            reset_sink_reset_n         => pll_locked,
            adc_pll_clock_clk          => clk_10MHz_pll,
            adc_pll_locked_export      => pll_locked,
            sequencer_csr_address      => '0',
            sequencer_csr_read         => '0',
            sequencer_csr_write        => seq_write,
            sequencer_csr_writedata    => seq_writedata,
            sequencer_csr_readdata     => open,
            sample_store_csr_address   => "0000000",
            sample_store_csr_read      => '1',
            sample_store_csr_write     => '0',
            sample_store_csr_writedata => (others => '0'),
            sample_store_csr_readdata  => adc_dout_32,
            sample_store_irq_irq       => adc_eoc
        );

    adc_dout <= to_integer(unsigned(adc_dout_32(11 downto 0)));

    ---------------------------------------------------------
    -- 10 MHz process: two-stage synchronizer for EOC
    ---------------------------------------------------------
    process(clk_10MHz_pll)
    begin
        if rising_edge(clk_10MHz_pll) then
            eoc_sync1 <= adc_eoc;
            eoc_sync2 <= eoc_sync1;
            if eoc_sync2 = '1' then
                eoc_latch <= '1';
            elsif state = CAPTURE then
                eoc_latch <= '0';
            end if;
        end if;
    end process;

    ---------------------------------------------------------
    -- Sequencer init process
    ---------------------------------------------------------
    process(clk_10MHz_pll)
    begin
        if rising_edge(clk_10MHz_pll) then
            if pll_locked = '0' then
                seq_init_done <= '0';
                seq_write     <= '0';
                seq_writedata <= (others => '0');
            elsif seq_init_done = '0' then
                seq_write     <= '1';
                seq_writedata <= x"00000001";
                seq_init_done <= '1';
            else
                seq_write     <= '0';
                seq_writedata <= (others => '0');
            end if;
        end if;
    end process;

    ---------------------------------------------------------
    -- FSM + display process
    ---------------------------------------------------------
    process(clk_10MHz_pll)
        variable temp_bin : unsigned(11 downto 0);
        variable bcd      : unsigned(15 downto 0);
        variable temp_c   : natural range 0 to 4095;
    begin
        if rising_edge(clk_10MHz_pll) then
            if pll_locked = '0' then
                state          <= WAIT_FOR_IRQ;
                capture_timer  <= (others => '0');
                sample_counter <= (others => '0');
                display_data   <= (others => '0');
            else
                case state is
                    when WAIT_FOR_IRQ =>
                        if eoc_latch = '1' then
                            capture_timer <= (others => '0');
                            state <= CAPTURE;
                        end if;

                    when CAPTURE =>
                        capture_timer <= capture_timer + 1;
                        if capture_timer >= 10 then
                            sample_counter <= sample_counter + 1;
                            if sample_counter >= 500000 then
                                sample_counter <= (others => '0');
                                -- Convert raw ADC code to Celsius
                                -- Formula: Temp(C) = (4476 - adc_dout) * 100 / 1635
                                temp_c := (4476 - adc_dout) * 100 / 1635;
                                display_data <= std_logic_vector(
                                    to_unsigned(temp_c, 12));
                            end if;
                            state <= WAIT_FOR_IRQ;
                        end if;

                    when others =>
                        state <= WAIT_FOR_IRQ;
                end case;
            end if;

            -- Double Dabble BCD conversion for display
            temp_bin := unsigned(display_data);
            bcd      := (others => '0');
            for i in 0 to 11 loop
                if bcd(3 downto 0)  >= 5 then bcd(3 downto 0)  := bcd(3 downto 0)  + 3; end if;
                if bcd(7 downto 4)  >= 5 then bcd(7 downto 4)  := bcd(7 downto 4)  + 3; end if;
                if bcd(11 downto 8) >= 5 then bcd(11 downto 8) := bcd(11 downto 8) + 3; end if;
                bcd      := bcd(14 downto 0) & temp_bin(11);
                temp_bin := temp_bin(10 downto 0) & '0';
            end loop;

            hex0_rec <= get_hex_digit(to_integer(bcd(3 downto 0)));
            hex1_rec <= get_hex_digit(to_integer(bcd(7 downto 4)));
            hex2_rec <= get_hex_digit(to_integer(bcd(11 downto 8)));
        end if;
    end process;

    -- Hardware mapping
    HEX0 <= hex0_rec.g & hex0_rec.f & hex0_rec.e & hex0_rec.d &
            hex0_rec.c & hex0_rec.b & hex0_rec.a;
    HEX1 <= hex1_rec.g & hex1_rec.f & hex1_rec.e & hex1_rec.d &
            hex1_rec.c & hex1_rec.b & hex1_rec.a;
    HEX2 <= hex2_rec.g & hex2_rec.f & hex2_rec.e & hex2_rec.d &
            hex2_rec.c & hex2_rec.b & hex2_rec.a;
    HEX3 <= (others => '1');
    HEX4 <= (others => '1');
    HEX5 <= (others => '1');

    LEDR(0)          <= pll_locked;
    LEDR(1)          <= adc_eoc;
    LEDR(2)          <= eoc_latch;
    LEDR(9 downto 3) <= adc_dout_32(9 downto 3);

end architecture;