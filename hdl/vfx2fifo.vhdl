--! \file vfx2fifo.vhdl    Virtual FX2 FIFO Wrapper for VirtualFIFO
-- Software FIFO interface for GHDL simulator
--
-- (c) 2011, Martin Strubel <hackfin@section5.ch>
--
-- A virtual FIFO behaving like a FX2
--
-- This is the typically the interface between netpp and a VHDL simulation.
-- The word size is configureable (1, 2) using the WORDSIZE generic.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.virtual.all;
use work.ghpi_netpp.all;

--! \brief Virtual FX2 FIFO
--! Emulates a FX2 fifo with a software interface to speak to a netpp
--! client.

entity VirtualFX2Fifo is
	generic (
		NETPP_NAME   : string   := "DEFAULT"; --! Default NETPP name
		WORDSIZE     : natural := 1           --! Word size
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
end VirtualFX2Fifo;

architecture behaviour of VirtualFX2Fifo is
	-- FIFO timings:
-- FX2 compatible timings:
	constant T_SRD	 : time := 18.7 ns;
	constant T_XFLG  : time := 9.5 ns;
	constant T_XFD   : time := 11 ns;
	constant T_OEON  : time := 10.5 ns;
	constant T_OEOFF : time := 10.5 ns;

	constant DATA_WIDTH : natural := 8*WORDSIZE;

	signal fifo_flags :  fifoflag_t := "000000";

	-- FIFO readahead
	signal can_rx	  : std_logic := '0';
	signal can_tx	  : std_logic := '1';

	signal slrd   :  std_logic := '1';
	signal slwr   :  std_logic := '1';
	signal sloe   :  std_logic := '1';

	signal re     :  std_logic;
	signal we     :  std_logic;

	signal data	  :  std_logic_vector(DATA_WIDTH-1 downto 0)
		:= (others => '0');

begin

	-- /OE control
oectrl:
	process (u_sloe, data)
	begin
		if u_sloe = '0' then
			u_fd <= (others => 'Z');
			u_fd <= std_logic_vector(
				resize(unsigned(data), u_fd'length)) after T_OEON;
		else
			u_fd <= (others => 'Z') after T_OEOFF;
		end if;
	end process;

	virtual_fifo: VirtualFIFO
	generic map (
		NETPP_NAME => NETPP_NAME,
		WORDSIZE => WORDSIZE
	)
	port map (
		clk         => u_ifclk,
		throttle    => global_throttle,
		wr_ready    => can_tx,
		rd_ready    => can_rx,
		wr_enable   => we,
		rd_enable   => re,
		data_in     => data,
		data_out    => u_fd(8*WORDSIZE-1 downto 0)
	);

	we <= not slwr;
	re <= not slrd;

	u_flag(TX_EMPTY) <= can_rx after T_XFLG;
	u_flag(RX_FULL)  <= can_tx after T_XFLG;

	-- Simulate setup timing for internal signals:
	sloe <= u_sloe after T_OEON;
	slrd <= u_slrd after T_SRD;
	slwr <= u_slwr after T_SRD;

end behaviour;
