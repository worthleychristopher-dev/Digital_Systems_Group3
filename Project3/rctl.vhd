library ieee;
use ieee.std_logic_1164.all;

entity rctl is
    port (
        rclk    : in  std_logic;
        rrst_n  : in  std_logic;
        rget    : in  std_logic;
        rq2_wptr: in  std_logic;
        rrdy    : out std_logic;
        rptr    : out std_logic
    );
end entity rctl;

architecture rtl of rctl is
    signal rptr_r : std_logic := '0';
    signal rrdy_s : std_logic;
    signal rinc   : std_logic;
begin
    -- FIFO has data when read pointer differs
    -- from synchronized write pointer
    rrdy_s <= rq2_wptr xor rptr_r;
    rinc   <= rrdy_s and rget;

    process(rclk, rrst_n)
    begin
        if rrst_n = '0' then
            rptr_r <= '0';
        elsif rising_edge(rclk) then
            rptr_r <= rptr_r xor rinc;
        end if;
    end process;

    rrdy <= rrdy_s;
    rptr <= rptr_r;
end architecture rtl;