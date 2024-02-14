library ieee;
use ieee.std_logic_1164.all;

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
    constant N : integer := 50000100;
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
    begin
		test_runner_setup(runner, runner_cfg);
		-- COUNTING FROM 0 ns to 1 s TEST
        -- rst <= '1';
        -- wait for T;
        -- rst <= '0';
        -- for i in 0 to N loop
            -- clk <= '1';
            -- wait for T/2;
            -- clk <= '0';
            -- wait for T/2;
        -- end loop;
		
		-- SET + COUNTING TEST
		-- clk <= '0';
		-- time_in <= "01100101101110111000110000100010";
		-- set <= '1';
		-- wait for T/2;
		-- clk <= '1';
		-- wait for T/2;
		-- set <= '0';
		-- time_in <= (others => '0');
		-- for i in 0 to 1000 loop
            -- clk <= '0';
            -- wait for T/2;
            -- clk <= '1';
            -- wait for T/2;
        -- end loop;
        report "Done";
        test_runner_cleanup(runner);
		wait;
    end process;
end arch;