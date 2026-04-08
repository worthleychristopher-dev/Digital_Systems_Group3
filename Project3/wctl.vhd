library ieee;
use ieee.std_logic_1164.all;

entity wctl is
    port (
        wclk    : in  std_logic;
        wrst_n  : in  std_logic;
        wput    : in  std_logic;
        wq2_rptr: in  std_logic;
        wrdy    : out std_logic;
        wptr    : out std_logic;
        we      : out std_logic
    );
end entity wctl;

architecture rtl of wctl is
    signal wptr_r : std_logic := '0';
    signal we_s   : std_logic;
    signal wrdy_s : std_logic;
begin
    -- FIFO is ready when write pointer equals
    -- the synchronized read pointer
    wrdy_s <= not (wq2_rptr xor wptr_r);
    we_s   <= wrdy_s and wput;

    process(wclk, wrst_n)
    begin
        if wrst_n = '0' then
            wptr_r <= '0';
        elsif rising_edge(wclk) then
            wptr_r <= wptr_r xor we_s;
        end if;
    end process;

    wrdy <= wrdy_s;
    wptr <= wptr_r;
    we   <= we_s;
end architecture rtl;
