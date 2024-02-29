library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library design_lib;

entity interrupt_tb is
    generic (runner_cfg : string);
end interrupt_tb;

architecture arch of interrupt_tb is
	signal clk : std_logic := '0';
	signal rst : std_logic := '0';
	signal read : std_logic := '0';
	signal write : std_logic := '0';
	signal waitrequest : std_logic := '0';
	signal address : std_logic_vector(31 downto 0) := (others => '0');
	signal readdata : std_logic_vector(31 downto 0) := (others => '0');
	signal writedata : std_logic_vector(31 downto 0) := (others => '0');
	signal byteenable : std_logic_vector(3 downto 0) := (others => '0');
	signal readdatavalid : std_logic;
	signal burstcount : std_logic_vector(1 downto 0) := (others => '0');
	signal sys_output : std_logic := '0';
    signal interrupt : std_logic := '0';
	signal timer : integer := -80;
	
	constant avmm_bus : bus_master_t := new_bus(
		data_length => 32,
		address_length => 32,
		logger => get_logger("avmm_bus")
	);

	constant T : time := 20 ns;

    begin
        dut : entity design_lib.register_file port map(
            clk_i => clk,
            rst_i => rst,
            av_read_i => read,
            av_write_i => write,
            av_address_i => address,
            av_writedata_i => writedata,
            av_readdata_o => readdata,
            av_waitrequest_o => waitrequest,
            sys_output_o => sys_output,
            interrupt_o => interrupt
        );
    
        avmm_master : entity vunit_lib.avalon_master
        generic map(
            bus_handle => avmm_bus,
            use_readdatavalid => false
        )
        port map(
            clk => clk,
            address => address,
            byteenable => byteenable,
            burstcount => burstcount,
            waitrequest => waitrequest,
            write => write,
            writedata => writedata,
            read => read,
            readdata => readdata,  
            readdatavalid => readdatavalid
        );
    
        clk_gen : process
        begin
            clk <= '0';
            wait for T/2;
            clk <= '1';
            wait for T/2;
        end process;

        timer_inc : process(clk)
        begin
            if rising_edge(clk) then
                timer <= timer + 20;
            end if;
        end process;

        interrupt_tst : process
	begin
		test_runner_setup(runner, runner_cfg);
		set_stop_level(failure);
		show(get_logger(default_checker), display_handler, pass);
       
        info("Test start...");

        rst <= '1';
		wait for T/2;
		rst <= '0';

        -- Assert IE flag
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(0, address'length)), std_logic_vector(to_unsigned(50, address'length)));
		wait_until_idle(net, avmm_bus);
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(2, address'length)), std_logic_vector(to_unsigned(2, address'length)));
        wait_until_idle(net, avmm_bus);
        wait for T;
        check(interrupt= '1' , "Checking if interrupt asserted when FIFO bafer is empty.");
        wait for T;
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(50000, writedata'length)));
		wait_until_idle(net, avmm_bus);
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned(1000, writedata'length)));
		wait_until_idle(net, avmm_bus);
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(50000, writedata'length)));
		wait_until_idle(net, avmm_bus);
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned(1000, writedata'length)));
		wait_until_idle(net, avmm_bus);
		
		-- Clear status register
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, address'length)));
        wait_until_idle(net, avmm_bus);
		wait for T;
		check(interrupt= '0' , "Checking if interrupt is not asserted when FIFO bafer is not empty.");
        write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(0, writedata'length)));
		wait_until_idle(net, avmm_bus);
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned(1000, writedata'length)));
		wait_until_idle(net, avmm_bus);
		wait for T;
		check(interrupt= '1' , "Checking if interrupt asserted when SYS time error.");
		-- Clear status register
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(1, address'length)), std_logic_vector(to_unsigned(0, address'length)));
        wait_until_idle(net, avmm_bus);
		wait for T;
		check(interrupt= '0' , "Checking if interrupt is not asserted when cleared.");
	
        for i in 0 to 7 loop
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(5, address'length)), std_logic_vector(to_unsigned(1500, writedata'length)));
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(6, address'length)), std_logic_vector(to_unsigned((i+1)*60000, writedata'length)));
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(3, address'length)), std_logic_vector(to_unsigned(1500, writedata'length)));
			wait_until_idle(net, avmm_bus);
			write_bus(net, avmm_bus, std_logic_vector(to_unsigned(4, address'length)), std_logic_vector(to_unsigned((i+1)*80000, writedata'length)));
			wait_until_idle(net, avmm_bus);
			
		end loop;
		wait for T;
		check(interrupt= '1' , "Checking if interrupt asserted when FIFO bafer is full.");
		wait for T;
        --Clear interrupt enable
		write_bus(net, avmm_bus, std_logic_vector(to_unsigned(2, address'length)), std_logic_vector(to_unsigned(0, address'length)));
        wait_until_idle(net, avmm_bus);
	    wait for T;
		check(interrupt= '0' , "Checking if interrupt is cleared.");
		
		test_runner_cleanup(runner);
        
		wait;
	end process;

	test_runner_watchdog(runner, 20 us);
end arch;