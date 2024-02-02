library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_logic is
  port(
    clk_i          : in std_logic;
    rst_i          : in std_logic;
    value_i        : in std_logic_vector(31 downto 0);
    counter_time_i : in std_logic_vector(63 downto 0);
    user_time_i    : in std_logic_vector(63 downto 0);
    system_o       : out std_logic
  );
end output_logic;

architecture arch of output_logic is
  signal q_cmp       : std_logic;
  signal val_decoded : std_logic;
  signal q_reg       : std_logic;
  signal q_next      : std_logic;
begin
  -- comparator logic
  process(counter_time_i, user_time_i)
  begin
    if counter_time_i = user_time_i then
      q_cmp <= '1';
    else
      q_cmp <= '0';
    end if;
  end process;
  
  -- D-FF logic
  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      q_reg <= '0';
    elsif rising_edge(clk_i) then
	   q_reg <= q_next;
    end if;
  end process;
  
  -- VALUE decoder
  process(value_i)
  begin
    if value_i = "11111111111111111111111111111111" then
	   val_decoded <= '1';
	 else
	   val_decoded <= '0';
	 end if;
  end process;
  
  -- next-state logic
  q_next <= val_decoded when q_cmp = '1' else q_reg;
  
  -- output logic
  system_o <= q_reg;
end arch;
  
  
