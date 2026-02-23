-- toplevel.vhd
-- Control unit + RAM storage for all possible challenges.
-- SIMPLE manual readback interface (no JTAG tools needed):
--   - sw[5:0] selects RAM address after done=1
--   - led_data outputs stored bit at that address
--
-- VHDL-1993 compatible.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toplevel is
  generic (
    clock_freq    : positive := 50_000_000; -- Hz
    probe_delay   : positive := 10000;       -- microseconds
    ro_length     : positive := 13;
    ro_count      : positive := 16;
    counter_width : positive := 16
  );
  port (
    reset      : in  std_logic;  -- async active-low reset for control unit
    clock      : in  std_logic;  -- FPGA clock (50 MHz on DE10-Lite)

    -- Manual RAM readback (simple + reliable)
    sw         : in  std_logic_vector(5 downto 0); -- address select (SW[5:0])
    led_data   : out std_logic;                    -- stored bit (map to LEDR1)

    -- Status/debug
    done       : out std_logic;  -- map to LEDR0
    dbg_enable : out std_logic;  -- optional
    dbg_resp   : out std_logic   -- optional
  );
end entity;

architecture rtl of toplevel is

  -- ========= FUNCTIONS =========

  function is_power_of_two(x : positive) return boolean is
    variable v : natural := x;
  begin
    while (v mod 2 = 0) loop
      v := v / 2;
    end loop;
    return (v = 1);
  end function;

  function clog2(x : positive) return natural is
    variable v : natural := x - 1;
    variable r : natural := 0;
  begin
    while v > 0 loop
      v := v / 2;
      r := r + 1;
    end loop;
    return r;
  end function;

  -- ========= CONSTANTS =========

  constant b            : natural := clog2(ro_count);
  constant chall_w      : natural := 2 * (b - 1);
  constant probe_cycles : natural := (clock_freq * probe_delay) / 1_000_000;

  -- ========= SIGNALS to ro_puf =========

  signal puf_reset     : std_logic := '0'; -- active-low
  signal puf_enable    : std_logic := '0';
  signal puf_challenge : std_logic_vector(chall_w-1 downto 0) := (others => '0');
  signal puf_response  : std_logic;

  -- ========= DONE internal (VHDL-93 can't read 'out' ports) =========
  signal done_int : std_logic := '0';

  -- ========= RAM IP interface =========
  signal ram_addr : std_logic_vector(5 downto 0);
  signal ram_din  : std_logic_vector(0 downto 0);
  signal ram_dout : std_logic_vector(0 downto 0);
  signal ram_we   : std_logic := '0';

  -- ========= FSM =========

  type state_t is (
    S_IDLE,
    S_ASSERT_RESET,
    S_SET_CHALLENGE,
    S_RELEASE_RESET,
    S_ENABLE,
    S_WAIT,
    S_DISABLE,
    S_WRITE,
    S_NEXT,
    S_DONE
  );

  signal state : state_t := S_IDLE;

  signal chall_ctr : unsigned(chall_w-1 downto 0) := (others => '0');
  signal wait_ctr  : unsigned(31 downto 0) := (others => '0');

  constant LAST_CHALLENGE : unsigned(chall_w-1 downto 0) := (others => '1');

begin

  -- Drive output port from internal signal (VHDL-93 safe)
  done <= done_int;

  -- ========= Sanity checks =========

  assert (ro_count >= 2)
    report "toplevel: ro_count must be >= 2."
    severity failure;

  assert is_power_of_two(ro_count)
    report "toplevel: ro_count must be power of two."
    severity failure;

  -- ========= RAM interface wiring =========

  -- Data in is always the current response bit (only written when ram_we='1')
  ram_din(0) <= puf_response;

  -- Write enable during S_WRITE
  ram_we <= '1' when state = S_WRITE else '0';

  -- SINGLE DRIVER for ram_addr (fixes your multiple-driver error):
  -- While running: address = challenge counter
  -- After done:    address = switches (manual readback)
  ram_addr <= sw when done_int = '1' else std_logic_vector(chall_ctr);

  -- ========= Instantiate RAM IP =========
  u_ram : entity work.RAM_IP
    port map (
      address => ram_addr,
      clock   => clock,
      data    => ram_din,
      wren    => ram_we,
      q       => ram_dout
    );

  -- ========= Instantiate RO-PUF =========

  u_puf : entity work.ro_puf
    generic map (
      ro_length     => ro_length,
      ro_count      => ro_count,
      counter_width => counter_width
    )
    port map (
      reset     => puf_reset,
      enable    => puf_enable,
      challenge => puf_challenge,
      response  => puf_response
    );

  -- ========= Control FSM =========

  process(clock, reset)
  begin
    if reset = '0' then
      state         <= S_IDLE;
      done_int      <= '0';
      puf_reset     <= '0';
      puf_enable    <= '0';
      puf_challenge <= (others => '0');
      chall_ctr     <= (others => '0');
      wait_ctr      <= (others => '0');

    elsif rising_edge(clock) then
      case state is

        when S_IDLE =>
          done_int   <= '0';
          puf_enable <= '0';
          puf_reset  <= '0';
          chall_ctr  <= (others => '0');
          wait_ctr   <= (others => '0');
          state      <= S_ASSERT_RESET;

        when S_ASSERT_RESET =>
          -- 1) Assert reset to ro_puf counters (active-low)
          puf_reset  <= '0';
          puf_enable <= '0';
          state      <= S_SET_CHALLENGE;

        when S_SET_CHALLENGE =>
          -- 2) Provide challenge
          puf_challenge <= std_logic_vector(chall_ctr);
          state         <= S_RELEASE_RESET;

        when S_RELEASE_RESET =>
          -- 3) Deassert reset
          puf_reset <= '1';
          state     <= S_ENABLE;

        when S_ENABLE =>
          -- 4) Enable counting
          puf_enable <= '1';
          wait_ctr   <= (others => '0');
          state      <= S_WAIT;

        when S_WAIT =>
          -- 5) Wait probe_delay us
          if to_integer(wait_ctr) >= integer(probe_cycles) then
            state <= S_DISABLE;
          else
            wait_ctr <= wait_ctr + 1;
          end if;

        when S_DISABLE =>
          -- 6) Stop counting
          puf_enable <= '0';
          state      <= S_WRITE;

        when S_WRITE =>
          -- 7) Store result in RAM at address = challenge
          -- Actual write occurs in RAM_IP via ram_we/ram_addr/ram_din
          state <= S_NEXT;

        when S_NEXT =>
          if chall_ctr = LAST_CHALLENGE then
            state <= S_DONE;
          else
            chall_ctr <= chall_ctr + 1;
            state     <= S_ASSERT_RESET;
          end if;

        when S_DONE =>
          done_int   <= '1';
          puf_enable <= '0';
          puf_reset  <= '1';
          state      <= S_DONE;

        when others =>
          state <= S_IDLE;

      end case;
    end if;
  end process;

  -- Manual readback output
  led_data <= ram_dout(0);

  -- Debug outputs
  dbg_enable <= puf_enable;
  dbg_resp   <= puf_response;

end architecture;