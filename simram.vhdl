library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

library ghdlex;
-- The RAM functions are generated within the netpp autowrapper
	use ghdlex.ghpi_netpp.all;
	use ghdlex.virtual.all;
	use ghdlex.txt_util.all;
use std.textio.all;


entity simram is
end simram;

architecture simulation of simram is
	signal clk: std_logic := '0';
	signal we: std_logic := '0';
	constant ADDR_W : natural := 12;
	signal addr: unsigned(ADDR_W-1 downto 0) := (others => '0');
	signal data0: unsigned(31 downto 0);
	signal data1: unsigned(15 downto 0);
	signal data2: unsigned(15 downto 0);

begin

clkgen:
	process
		variable err : integer;
	begin
		err := netpp_init("VirtualRAM");
		clkloop : loop
			wait for 10 us;
			clk <= not clk;
			-- if sigterm = '1' then
				-- exit;
			-- end if;
		end loop clkloop;
		print(output, " -- TERMINATED --");
		-- fifo_thread_exit;

	end process;

ram0:
	DualPort16
	generic map (
		-- NETPP_NAME => "LowWord", -- You could enable an explicit name
		ADDR_W => ADDR_W
	)
	port map (
		clk     => clk,
		-- Port A
		a_we    => we,
		a_addr  => addr,
		a_write => data0(15 downto 0),
		a_read  => data1,
		-- Port B
		b_we    => '0',
		b_addr  => addr,
		b_write => data0(15 downto 0),
		b_read  => open
	);

ram1:
	DualPort16 generic map (
		-- NETPP_NAME => "HighWord", -- You could enable an explicit name
		ADDR_W => ADDR_W
	)
	port map (
		clk     => clk,
		-- Port A
		a_we    => we,
		a_addr  => addr,
		a_write => data0(31 downto 16),
		a_read  => data2,
		-- Port B
		b_we    => '0',
		b_addr  => addr,
		b_write => data0(31 downto 16),
		b_read  => open
	);

stim:
	process
	begin
		we <= '0';
		data0 <= x"deadbeef";
		addr <= "000000000001";
		wait for 40 us;
		we <= '1';
		wait for 20 us;
		we <= '0';
		wait for 20 us;

		data0 <= x"f00dface";
		addr <= "000000000010";
		wait;
	end process;

end simulation;
