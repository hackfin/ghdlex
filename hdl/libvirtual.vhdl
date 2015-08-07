--! \file libvirtual.vhdl Virtual entities package


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all; -- Unsigned

--! \brief Virtual entity package
--! Contains a number of virtual entities that are accessible through
--! netpp.

package virtual is

	component VirtualFIFO is
		generic (
			NETPP_NAME   : string   := "DEFAULT";
			FIFOSIZE     : natural     := 512;
			SLEEP_CYCLES : natural := 50000;
			WORDSIZE     : natural     := 1
		);
		port (
			signal clk         : in  std_logic;
			signal throttle    : in  std_logic;
			signal wr_ready    : out std_logic;
			signal rd_ready    : out std_logic;
			signal wr_enable   : in  std_logic;
			signal rd_enable   : in  std_logic;
			signal data_in     : out std_logic_vector(8*WORDSIZE-1 downto 0);
			signal data_out    : in  std_logic_vector(8*WORDSIZE-1 downto 0)
		);
	end component;

	-- A FIFO emulation for a Cypress FX2
	component VirtualFX2Fifo
		generic (
			NETPP_NAME   : string   := "DEFAULT";
			WORDSIZE     : natural := 1
		);
		port (
			u_ifclk      : in std_logic; -- USB interface clock
			u_slwr       : in std_logic;
			u_slrd       : in std_logic;
			u_sloe       : in std_logic;
			u_pktend     : out std_logic;
			u_flag       : out std_logic_vector(2 downto 0);  -- Status flags
			u_fifoadr    : in std_logic_vector(1 downto 0);
			u_fd         : inout std_logic_vector(15 downto 0)
		);
	end component;


	component DualPort16 is
		generic(
			NETPP_NAME   : string   := "DEFAULT";
			ADDR_W       : natural  := 14
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
			NETPP_NAME   : string  := "DEFAULT";
			ADDR_W       : natural := 8;
			DATA_W       : natural := 32;
			BUSTYPE      : natural := 1
		);
		port (
			clk         : in  std_logic;
			wr          : out std_logic;
			rd          : out std_logic;
			wr_busy     : in  std_logic;
			rd_busy     : in  std_logic;
			addr        : out std_logic_vector(ADDR_W-1 downto 0);
			data_in     : out std_logic_vector(DATA_W-1 downto 0);
			data_out    : in  std_logic_vector(DATA_W-1 downto 0)
		);
	end component VirtualBus;

end package;

