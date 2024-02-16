library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library design_lib;

entity fifo_buffer_tb is
    generic (runner_cfg : string);
end fifo_buffer_tb;

architecture arch of fifo_buffer_tb is

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal write_en : std_logic := '0';
    signal read_en : std_logic := '0';
    signal buf_full : std_logic := '0';
    signal buf_empty : std_logic := '0';
    signal write_data : std_logic_vector(95 downto 0) := (others => '0');
    signal read_data : std_logic_vector(95 downto 0) := (others => '0');

    constant T : time := 20 ns;

    type test_array_t is array(0 to 7) of unsigned(95 downto 0);
    signal test_array : test_array_t := (
        to_unsigned(1250, read_data'length),
        to_unsigned(2500, read_data'length),
        to_unsigned(4000, read_data'length),
        to_unsigned(6500, read_data'length),
        to_unsigned(9850, read_data'length),
        to_unsigned(10950, read_data'length),
        to_unsigned(12500, read_data'length),
        to_unsigned(25000, read_data'length)
    );

    constant vector1 : std_logic_vector (95 downto 0) := (others => '1');
    constant vector2 : std_logic_vector (95 downto 0) := (others => '0');
begin
    uut : entity design_lib.fifo_buffer 
    generic map(
        g_DEPTH => 8
    )
    port map(
        clk_i => clk,
        rst_i => rst,
        write_en_i => write_en,
        read_en_i => read_en,
        write_data_i => write_data,
        read_data_o => read_data,
        buf_full_o  => buf_full,
        buf_empty_o => buf_empty
    );

    clk_gen : process
    begin
        clk <= '0';
        wait for T/2;
        clk <= '1';
        wait for T/2;
    end process;

    rst_gen : process
    begin
        rst <= '1';
        wait for T/4;
        rst <= '0';
        wait;
    end process;

    stim_gen : process
    begin
        test_runner_setup(runner, runner_cfg);
		set_stop_level(failure);
		show(get_logger(default_checker), display_handler, pass);
		write_en <= '1';
        for i in 0 to 7 loop
            write_data <= std_logic_vector(test_array(i));
            wait for T;
        end loop;
        write_en <= '0';

		check(buf_full = '1', "Checking that FIFO buffer is full after insertions");
        
        read_en <= '1';
        for i in 0 to 7 loop
			check_equal(test_array(i), unsigned(read_data), "Comparing pushed value from FIFO buffer at index " & integer'image(i));
            wait for T;
        end loop;
        read_en <= '0';
		
		check(buf_empty = '1', "Checking that FIFO buffer is empty after removals");
		
        write_en <= '1';
        for i in 0 to 7 loop
            write_data <= std_logic_vector(test_array(i));
            wait for T;
        end loop;
        write_data <= vector1;
        wait for T;
        write_data <= vector2;
        wait for T;
        write_en <= '0';
		
        read_en <= '1';
		check_equal(unsigned(vector1), unsigned(read_data), "Comparing first overwrite value");
        wait for T;
		check_equal(unsigned(vector2), unsigned(read_data), "Comparing first overwrite value");
        wait for T;
        read_en <= '0';
		
        test_runner_cleanup(runner);
		wait;
	end process;
end arch;