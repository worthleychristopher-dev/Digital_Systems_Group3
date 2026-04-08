library ieee;
use ieee.std_logic_1164.all;

entity cdc_fifo is
    generic (
        data_width : positive := 12
    );
    port (
        -- Write (producer) side - 10 MHz
        wclk   : in  std_logic;
        wrst_n : in  std_logic;
        wdata  : in  std_logic_vector(data_width - 1 downto 0);
        wput   : in  std_logic;
        wrdy   : out std_logic;
        -- Read (consumer) side - 50 MHz
        rclk   : in  std_logic;
        rrst_n : in  std_logic;
        rdata  : out std_logic_vector(data_width - 1 downto 0);
        rget   : in  std_logic;
        rrdy   : out std_logic
    );
end entity cdc_fifo;

architecture rtl of cdc_fifo is

    -- Internal pointer signals
    signal wptr     : std_logic;
    signal rptr     : std_logic;
    signal we       : std_logic;
    signal wq2_rptr : std_logic_vector(0 downto 0);
    signal rq2_wptr : std_logic_vector(0 downto 0);
    signal wptr_vec : std_logic_vector(0 downto 0);
    signal rptr_vec : std_logic_vector(0 downto 0);

    -- 2-deep dual port RAM
    type ram_t is array (0 to 1) of
        std_logic_vector(data_width - 1 downto 0);
    signal mem : ram_t := (others => (others => '0'));

begin

    -- Write controller
    U_WCTL : entity work.wctl
        port map (
            wclk     => wclk,
            wrst_n   => wrst_n,
            wput     => wput,
            wq2_rptr => wq2_rptr(0),
            wrdy     => wrdy,
            wptr     => wptr,
            we       => we
        );

    -- Read controller
    U_RCTL : entity work.rctl
        port map (
            rclk     => rclk,
            rrst_n   => rrst_n,
            rget     => rget,
            rq2_wptr => rq2_wptr(0),
            rrdy     => rrdy,
            rptr     => rptr
        );

    -- Synchronize write pointer into read domain
    wptr_vec(0) <= wptr;
    U_W2R : entity work.sync2
        generic map (width => 1)
        port map (
            clk   => rclk,
            rst_n => rrst_n,
            d     => wptr_vec,
            q     => rq2_wptr
        );

    -- Synchronize read pointer into write domain
    rptr_vec(0) <= rptr;
    U_R2W : entity work.sync2
        generic map (width => 1)
        port map (
            clk   => wclk,
            rst_n => wrst_n,
            d     => rptr_vec,
            q     => wq2_rptr
        );

    -- Dual port 2-deep RAM
    -- Write port clocked on wclk
    process(wclk)
    begin
        if rising_edge(wclk) then
            if we = '1' then
                if wptr = '0' then
                    mem(0) <= wdata;
                else
                    mem(1) <= wdata;
                end if;
            end if;
        end if;
    end process;

    -- Read port combinational
    rdata <= mem(0) when rptr = '0' else mem(1);

end architecture rtl;