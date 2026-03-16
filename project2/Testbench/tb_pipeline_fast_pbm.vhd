library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

library ads;
use ads.ads_fixed.all;
use ads.ads_complex_pkg.all;

use work.pipeline_pkg.all;

entity tb_pipeline_fast_pbm is
end entity;

architecture sim of tb_pipeline_fast_pbm is
    constant CLK_PERIOD : time := 25 ns;

    constant WIDTH      : natural := 800;
    constant HEIGHT     : natural := 600;
    constant ITERATIONS : natural := 16;

    constant THRESHOLD  : ads_sfixed := to_ads_sfixed(4);
    constant OFFSET     : ads_complex := (
        re => to_ads_sfixed(-1.5),
        im => to_ads_sfixed(-1.0)
    );
    constant ZOOM       : ads_sfixed := to_ads_sfixed(0.5);
    constant STEP       : ads_sfixed := (to_ads_sfixed(1) / ZOOM) / to_ads_sfixed(HEIGHT);

    constant PIPE_LATENCY : natural := ITERATIONS * 3;

    signal clock : std_logic := '0';
    signal reset : std_logic := '0';

    signal chain : pipeline_bus(0 to ITERATIONS);
    signal pipe_in : pipeline_register := (
        z => complex_zero,
        c => complex_zero,
        stage_data => 0,
        stage_overflow => false,
        stage_valid => false
    );

    type frame_row_t is array (0 to WIDTH-1) of integer;
    type frame_t is array (0 to HEIGHT-1) of frame_row_t;

    type nat_array_t is array (natural range <>) of natural;
    type bool_array_t is array (natural range <>) of boolean;

    signal x_pipe : nat_array_t(0 to PIPE_LATENCY);
    signal y_pipe : nat_array_t(0 to PIPE_LATENCY);
    signal v_pipe : bool_array_t(0 to PIPE_LATENCY);

begin
    clock <= not clock after CLK_PERIOD/2;

    chain(0) <= pipe_in;

    gen_pipeline : for i in 0 to ITERATIONS - 1 generate
        stage_i : entity work.pipeline_stage
            generic map (
                threshold    => THRESHOLD,
                stage_number => i
            )
            port map (
                reset        => reset,
                clock        => clock,
                stage_input  => chain(i),
                stage_output => chain(i + 1)
            );
    end generate;

    process
        file pbm_file : text open write_mode is "mandelbrot_800x600.pbm";
        variable L : line;

        variable frame : frame_t;

        variable x, y : natural := 0;
        variable feed_count : natural := 0;
        variable drain_count : natural := 0;

        variable c_re, c_im : ads_sfixed;
        variable out_x, out_y : natural;
        variable pixel_on : integer;
    begin
        for yy in 0 to HEIGHT - 1 loop
            for xx in 0 to WIDTH - 1 loop
                frame(yy)(xx) := 0;
            end loop;
        end loop;

        reset <= '0';
        pipe_in <= (
            z => complex_zero,
            c => complex_zero,
            stage_data => 0,
            stage_overflow => false,
            stage_valid => false
        );

        wait for 100 ns;
        wait until rising_edge(clock);
        reset <= '1';

        while feed_count < WIDTH * HEIGHT loop
            wait until rising_edge(clock);

            c_re := OFFSET.re + (to_ads_sfixed(integer(x)) * STEP);
            c_im := OFFSET.im + (to_ads_sfixed(integer(y)) * STEP);

            pipe_in <= (
                z => complex_zero,
                c => (re => c_re, im => c_im),
                stage_data => 0,
                stage_overflow => false,
                stage_valid => true
            );

            x_pipe(0) <= x;
            y_pipe(0) <= y;
            v_pipe(0) <= true;

            for i in 1 to PIPE_LATENCY loop
                x_pipe(i) <= x_pipe(i - 1);
                y_pipe(i) <= y_pipe(i - 1);
                v_pipe(i) <= v_pipe(i - 1);
            end loop;

            if v_pipe(PIPE_LATENCY) then
                out_x := x_pipe(PIPE_LATENCY);
                out_y := y_pipe(PIPE_LATENCY);

                if chain(ITERATIONS).stage_data = 15 then
                    pixel_on := 0;
                else
                    pixel_on := 1;
                end if;

                if out_x < WIDTH and out_y < HEIGHT then
                    frame(out_y)(out_x) := pixel_on;
                end if;
            end if;

            if (feed_count mod 50000) = 0 then
                report "feed_count = " & integer'image(feed_count);
            end if;

            if x = WIDTH - 1 then
                x := 0;
                y := y + 1;
            else
                x := x + 1;
            end if;

            feed_count := feed_count + 1;
        end loop;

        report "Finished feeding pixels, draining pipeline";

        pipe_in <= (
            z => complex_zero,
            c => complex_zero,
            stage_data => 0,
            stage_overflow => false,
            stage_valid => false
        );

        while drain_count < PIPE_LATENCY + 5 loop
            wait until rising_edge(clock);

            x_pipe(0) <= 0;
            y_pipe(0) <= 0;
            v_pipe(0) <= false;

            for i in 1 to PIPE_LATENCY loop
                x_pipe(i) <= x_pipe(i - 1);
                y_pipe(i) <= y_pipe(i - 1);
                v_pipe(i) <= v_pipe(i - 1);
            end loop;

            if v_pipe(PIPE_LATENCY) then
                out_x := x_pipe(PIPE_LATENCY);
                out_y := y_pipe(PIPE_LATENCY);

                if chain(ITERATIONS).stage_data = 15 then
                    pixel_on := 0;
                else
                    pixel_on := 1;
                end if;

                if out_x < WIDTH and out_y < HEIGHT then
                    frame(out_y)(out_x) := pixel_on;
                end if;
            end if;

            if (drain_count mod 10) = 0 then
                report "drain_count = " & integer'image(drain_count);
            end if;

            drain_count := drain_count + 1;
        end loop;

        report "Writing PBM file";

        write(L, string'("P1"));
        writeline(pbm_file, L);

        L := null;
        write(L, WIDTH);
        write(L, string'(" "));
        write(L, HEIGHT);
        writeline(pbm_file, L);

        for yy in 0 to HEIGHT - 1 loop
            L := null;
            for xx in 0 to WIDTH - 1 loop
                write(L, frame(yy)(xx));
                if xx < WIDTH - 1 then
                    write(L, string'(" "));
                end if;
            end loop;
            writeline(pbm_file, L);
        end loop;

        file_close(pbm_file);
        report "PBM file generated: mandelbrot_800x600.pbm";
        stop;
        wait;
    end process;

end architecture;