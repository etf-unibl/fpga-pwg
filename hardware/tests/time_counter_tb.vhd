library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
context vunit_lib.vunit_context;

library design_lib;

entity time_counter_tb is
    generic (runner_cfg : string);
end entity;

architecture arch of time_counter_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal set : std_logic := '0';
    signal time_in : std_logic_vector(31 downto 0);
    signal unix_time_out : std_logic_vector(31 downto 0);
    signal nano_time_out : std_logic_vector(31 downto 0);
    constant T : time := 20 ns;
	constant N : integer := 50000000;
	constant set_time : std_logic_vector(31 downto 0) := "01100101101110111000110000100010";
begin
    uut: entity design_lib.time_counter port map(
        clk_i => clk,
        rst_i => rst,
        set_i => set,
        time_i => time_in,
        time_o(63 downto 32) => unix_time_out,
        time_o(31 downto 0) => nano_time_out
    );
	

    process
		variable counter : integer := 0 ;
		variable loop_end : boolean := true;
    begin
		test_runner_setup(runner, runner_cfg);
		set_stop_level(failure);
		show(get_logger(default_checker), display_handler, pass);
		while test_suite loop
			if run("Counting to 1s") then
				rst <= '1';
				wait for T;
				rst <= '0';
				while loop_end loop
					clk <= '0';
					wait for T/2;
					clk <= '1';
					wait for T/2;
					counter := counter + 1;
					if counter = N then
						wait for T/2;
						check(unsigned(unix_time_out)=1, "Checking if unix_time incremented");
						loop_end := false;
					end if;
				end loop;
			
			elsif run("Set test.") then
				clk <= '0';
				time_in <= set_time;
				set <= '1';
				wait for T/2;
				clk <= '1';
				wait for T/2;
				set <= '0';
				time_in <= (others => '0');
				check(unsigned(unix_time_out)=unsigned(set_time), "Checking if set_time was set correctly");
				for i in 0 to 50 loop
					clk <= '0';
					wait for T/2;
					clk <= '1';
					wait for T/2;
				end loop; 
			end if;
        end loop;
        test_runner_cleanup(runner);
		wait;
    end process;
end arch;