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

    -------------------------------------------------------
    -- CLOCK SIGNALS
    -------------------------------------------------------
    signal clk_10MHz_pll : std_logic;
    signal pll_locked    : std_logic;

    -------------------------------------------------------
    -- PRODUCER SIDE SIGNALS (10 MHz domain)
    -------------------------------------------------------
    signal adc_eoc       : std_logic;
    signal adc_dout_32   : std_logic_vector(31 downto 0);
    signal adc_dout      : natural range 0 to 4095;
    signal adc_captured  : natural range 0 to 4095 := 0;

    signal eoc_sync1     : std_logic := '0';
    signal eoc_sync2     : std_logic := '0';
    signal eoc_latch     : std_logic := '0';

    -- Three state FSM with pipeline stage
    type prod_state_t is (WAIT_FOR_IRQ, CAPTURE, CONVERT);
    signal prod_state    : prod_state_t := WAIT_FOR_IRQ;
    signal capture_timer : unsigned(7 downto 0) := (others => '0');

    signal seq_init_done : std_logic := '0';
    signal seq_write     : std_logic := '0';
    signal seq_writedata : std_logic_vector(31 downto 0) := (others => '0');

    signal fifo_wdata    : std_logic_vector(11 downto 0) := (others => '0');
    signal fifo_wput     : std_logic := '0';
    signal fifo_wrdy     : std_logic;

    -------------------------------------------------------
    -- CONSUMER SIDE SIGNALS (50 MHz domain)
    -------------------------------------------------------
    signal fifo_rdata    : std_logic_vector(11 downto 0);
    signal fifo_rget     : std_logic := '0';
    signal fifo_rrdy     : std_logic;
    signal display_data  : std_logic_vector(11 downto 0) := (others => '0');
    signal hex0_rec, hex1_rec, hex2_rec : seven_segment_config;

    -------------------------------------------------------
    -- FIFO ACTIVITY LATCHES FOR LED DEBUG
    -------------------------------------------------------
    signal wput_latch    : std_logic := '0';
    signal rrdy_latch    : std_logic := '0';
    signal rget_latch    : std_logic := '0';

begin

    -------------------------------------------------------
    -- PLL INSTANTIATION
    -------------------------------------------------------
    U_PLL : entity work.adc_pll
        port map (
            areset => '0',
            inclk0 => ADC_CLK_10,
            c0     => clk_10MHz_pll,
            c1     => open,
            locked => pll_locked
        );

    -------------------------------------------------------
    -- MODULAR ADC CORE INSTANTIATION
    -------------------------------------------------------
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

    -------------------------------------------------------
    -- FIFO SYNCHRONIZER INSTANTIATION
    -------------------------------------------------------
    U_FIFO : entity work.cdc_fifo
        generic map (
            data_width => 12
        )
        port map (
            wclk   => clk_10MHz_pll,
            wrst_n => pll_locked,
            wdata  => fifo_wdata,
            wput   => fifo_wput,
            wrdy   => fifo_wrdy,
            rclk   => MAX10_CLK1_50,
            rrst_n => pll_locked,
            rdata  => fifo_rdata,
            rget   => fifo_rget,
            rrdy   => fifo_rrdy
        );

    -------------------------------------------------------
    -- PROCESS 1: EOC two-stage synchronizer (10 MHz)
    -------------------------------------------------------
    process(clk_10MHz_pll)
    begin
        if rising_edge(clk_10MHz_pll) then
            eoc_sync1 <= adc_eoc;
            eoc_sync2 <= eoc_sync1;
            if eoc_sync2 = '1' then
                eoc_latch <= '1';
            elsif prod_state = CAPTURE then
                eoc_latch <= '0';
            end if;
        end if;
    end process;

    -------------------------------------------------------
    -- PROCESS 2: Sequencer init (10 MHz)
    -------------------------------------------------------
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

    -------------------------------------------------------
    -- PROCESS 3: Producer FSM (10 MHz)
    -- Three states: WAIT_FOR_IRQ -> CAPTURE -> CONVERT
    -- CAPTURE saves raw ADC value
    -- CONVERT does the math next cycle (pipeline stage)
    -------------------------------------------------------
    process(clk_10MHz_pll)
    begin
        if rising_edge(clk_10MHz_pll) then
            fifo_wput <= '0';

            if pll_locked = '0' then
                prod_state    <= WAIT_FOR_IRQ;
                capture_timer <= (others => '0');
                adc_captured  <= 0;
                fifo_wdata    <= (others => '0');
                wput_latch    <= '0';
            else
                case prod_state is

                    when WAIT_FOR_IRQ =>
                        if eoc_latch = '1' then
                            capture_timer <= (others => '0');
                            prod_state    <= CAPTURE;
                        end if;

                    when CAPTURE =>
                        -- Wait for data to settle then save raw value
                        -- No division here - keeps this cycle fast
                        capture_timer <= capture_timer + 1;
                        if capture_timer >= 10 then
                            adc_captured <= adc_dout;
                            prod_state   <= CONVERT;
                        end if;

                    when CONVERT =>
                        -- Division happens here in its own dedicated cycle
                        -- This spreads the combinational depth across two cycles
                        fifo_wdata <= std_logic_vector(
                            to_unsigned(
                                (4476 - adc_captured) * 100 / 1635, 12));
                        if fifo_wrdy = '1' then
                            fifo_wput  <= '1';
                            wput_latch <= '1';
                        end if;
                        prod_state <= WAIT_FOR_IRQ;

                    when others =>
                        prod_state <= WAIT_FOR_IRQ;

                end case;
            end if;
        end if;
    end process;

    -------------------------------------------------------
    -- PROCESS 4: Consumer FSM + Display (50 MHz)
    -------------------------------------------------------
    process(MAX10_CLK1_50)
        variable temp_bin : unsigned(11 downto 0);
        variable bcd      : unsigned(15 downto 0);
    begin
        if rising_edge(MAX10_CLK1_50) then
            fifo_rget <= '0';

            if pll_locked = '0' then
                display_data  <= (others => '0');
                rrdy_latch    <= '0';
                rget_latch    <= '0';
            else
                if fifo_rrdy = '1' then
                    fifo_rget    <= '1';
                    display_data <= fifo_rdata;
                    rrdy_latch   <= '1';
                    rget_latch   <= '1';
                end if;
            end if;

            -- Double Dabble BCD conversion
            temp_bin := unsigned(display_data);
            bcd      := (others => '0');
            for i in 0 to 11 loop
                if bcd(3 downto 0)  >= 5 then
                    bcd(3 downto 0)  := bcd(3 downto 0)  + 3;
                end if;
                if bcd(7 downto 4)  >= 5 then
                    bcd(7 downto 4)  := bcd(7 downto 4)  + 3;
                end if;
                if bcd(11 downto 8) >= 5 then
                    bcd(11 downto 8) := bcd(11 downto 8) + 3;
                end if;
                bcd      := bcd(14 downto 0) & temp_bin(11);
                temp_bin := temp_bin(10 downto 0) & '0';
            end loop;

            hex0_rec <= get_hex_digit(to_integer(bcd(3 downto 0)));
            hex1_rec <= get_hex_digit(to_integer(bcd(7 downto 4)));
            hex2_rec <= get_hex_digit(to_integer(bcd(11 downto 8)));

        end if;
    end process;

    -------------------------------------------------------
    -- HARDWARE MAPPING
    -------------------------------------------------------
    HEX0 <= hex0_rec.g & hex0_rec.f & hex0_rec.e & hex0_rec.d &
            hex0_rec.c & hex0_rec.b & hex0_rec.a;
    HEX1 <= hex1_rec.g & hex1_rec.f & hex1_rec.e & hex1_rec.d &
            hex1_rec.c & hex1_rec.b & hex1_rec.a;
    HEX2 <= hex2_rec.g & hex2_rec.f & hex2_rec.e & hex2_rec.d &
            hex2_rec.c & hex2_rec.b & hex2_rec.a;
    HEX3 <= (others => '1');
    HEX4 <= (others => '1');
    HEX5 <= (others => '1');

    LEDR(0) <= pll_locked;
    LEDR(1) <= adc_eoc;
    LEDR(2) <= eoc_latch;
    LEDR(3) <= fifo_wrdy;
    LEDR(4) <= wput_latch;
    LEDR(5) <= rrdy_latch;
    LEDR(6) <= rget_latch;
    LEDR(9 downto 7) <= (others => '0');

end architecture;