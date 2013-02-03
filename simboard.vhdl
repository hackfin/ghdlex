-- A little more complex configuration
--
-- Test for various virtual entities

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all; -- Unsigned

library work;
	use work.ghpi_netpp.all;
	use work.virtual.all;
	use work.ghpi_fifo.all;
	use work.txt_util.all;

use std.textio.all;

entity simboard is
end simboard;

architecture simulation of simboard is
	signal clk: std_logic := '0';
	signal we: std_logic := '0';
	constant ADDR_W : natural := 12;
	signal addr: unsigned(ADDR_W-1 downto 0) := (others => '0');
	signal data0: unsigned(31 downto 0);
	signal data1: unsigned(15 downto 0);
	signal data2: unsigned(15 downto 0);

	type byte_bus_t is array (0 to 2) of std_logic_vector(7 downto 0);

	signal fifo_wready     : std_logic_vector(0 to 2);
	signal fifo_rready     : std_logic_vector(0 to 2);
	signal fifo_we         : std_logic_vector(0 to 2);
	signal fifo_re         : std_logic_vector(0 to 2);
	-- Note: Arrays of that kind are not yet supported by the wrapper
	signal fifo_din        : byte_bus_t;
	signal fifo_dout       : byte_bus_t;
begin

clkgen:
	process
		variable err : integer;
	begin
		-- err := fifo_thread_init("");
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
	DualPort16 generic map (ADDR_W => ADDR_W)
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
	DualPort16 generic map (ADDR_W => ADDR_W)
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

	-- Create a FIFO loopback:

nfifo:
	for i in 0 to 1 generate
fifo: VFIFO
	generic map (WORDSIZE => 1)
	port map (
		clk         => clk,
		wr_ready    => fifo_wready(i),
		rd_ready    => fifo_rready(i),
		wr_enable   => fifo_we(i),
		rd_enable   => fifo_re(i),
		data_in     => fifo_dout(i),
		data_out    => fifo_din(i)
	);
	end generate;

fifo_single: VFIFO
	generic map (WORDSIZE => 1)
	port map (
		clk         => clk,
		wr_ready    => fifo_wready(2),
		rd_ready    => fifo_rready(2),
		wr_enable   => fifo_we(2),
		rd_enable   => fifo_re(2),
		data_in     => fifo_dout(2),
		data_out    => fifo_din(2)
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
