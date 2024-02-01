library ieee;
use ieee.std_logic_1164.all;

entity time_counter_tb is
end entity;

architecture arch of time_counter_tb is
    component time_counter is
        port(
            clk_i  : in  std_logic; 
            rst_i  : in  std_logic; 
            set_i  : in  std_logic; 
            time_i : in  std_logic_vector(31 downto 0); 
            time_o : out std_logic_vector(63 downto 0) 
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal set : std_logic := '0';
    signal time_in : std_logic_vector(31 downto 0);
    signal unix_time_out : std_logic_vector(31 downto 0);
    signal nano_time_out : std_logic_vector(31 downto 0);
    constant T : time := 20 ns;
    constant N : integer := 50000100;
begin
    uut: time_counter port map(
        clk_i => clk,
        rst_i => rst,
        set_i => set,
        time_i => time_in,
        time_o(63 downto 32) => unix_time_out,
        time_o(31 downto 0) => nano_time_out
    );

    process
    begin
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
        wait;
    end process;
end arch;