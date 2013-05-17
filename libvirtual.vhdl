-- Virtual entities package

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all; -- Unsigned

package virtual is

	component VFIFO is
		generic (
			FIFOSIZE : natural := 512; --! FIFO size in number of words
			WORDSIZE : natural := 1    --! Word size in bytes (supported is 1, 2)
		);
		port (
			signal clk         : in  std_logic; --! The input master clock
			--! Signals by '1' when data is ready to be written
			signal wr_ready    : out std_logic;
			--! Signals by '1' when data is ready to be read
			signal rd_ready    : out std_logic;
			--! When '1', clock one data word into FIFO via data_in
			signal wr_enable   : in  std_logic;
			--! When '1', assert next data word from FIFO to data_out
			signal rd_enable   : in  std_logic;
			--! Data input
			signal data_in     : out std_logic_vector(8*WORDSIZE-1 downto 0);
			--! Data output
			signal data_out    : in  std_logic_vector(8*WORDSIZE-1 downto 0)
		);
	end component;

	component DualPort16 is
		generic(
			ADDR_W       : natural := 14
		);
		port(
			clk     : in  std_logic;
			-- Port A
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(16-1 downto 0);
			a_read  : out unsigned(16-1 downto 0);
			-- Port B
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(16-1 downto 0);
			b_read  : out unsigned(16-1 downto 0)
		);
	end component DualPort16;

	component VirtualBus
		generic (
			ADDR_W   : natural := 8;
			DATA_W   : natural := 32
		);
		port (
			clk         : in  std_logic; --! The input master clock
			wr          : out std_logic;
			rd          : out std_logic;
			addr        : out std_logic_vector(ADDR_W-1 downto 0);
			data_in     : out std_logic_vector(DATA_W-1 downto 0);
			data_out    : in  std_logic_vector(DATA_W-1 downto 0)
		);
	end component VirtualBus;

end package;

