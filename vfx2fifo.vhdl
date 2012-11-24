-- Software FIFO interface for GHDL simulator
--
-- (c) 2011, Martin Strubel <hackfin@section5.ch>
--
-- A virtual FIFO behaving like a FX2
--
-- This is the typically the interface between netpp and a VHDL simulation.
-- It can also be used without netpp.
-- The word size is configureable (1, 2) using the WORDSIZE generic.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ghpi_fifo.all;
use work.ghpi_netpp.all;

entity CFIFO is
	generic (
		WORDSIZE : natural := 1
	);
	port (
		u_ifclk      : in std_logic; -- USB interface clock
		u_slwr       : in std_logic;
		u_slrd       : in std_logic;
		u_sloe       : in std_logic;
		u_pktend     : out std_logic;
		u_flag       : out std_logic_vector(2 downto 0);  -- Status flags
		u_fifoadr    : in std_logic_vector(1 downto 0);
		u_fd         : inout std_logic_vector(15 downto 0);
		throttle     : in std_logic
	);
end CFIFO;

architecture behaviour of CFIFO is
	-- FIFO timings:
-- FX2 compatible timings:
	constant T_SRD	 : time := 18.7 ns;
	constant T_XFLG  : time := 9.5 ns;
	constant T_XFD   : time := 11 ns;
	constant T_OEON  : time := 10.5 ns;
	constant T_OEOFF : time := 10.5 ns;

	-- FLAG defines
	constant TX_PROG : natural := 0;
	constant TX_EMPTY : natural := 1;
	constant RX_FULL : natural := 2;

	constant DATA_WIDTH : natural := 8*WORDSIZE;

	signal fifo_flags :  fifoflag_t := "000000";

	-- FIFO readahead
	signal can_rx	  : std_logic := '0';
	signal can_tx	  : std_logic := '1';

	signal slrd   :  std_logic := '1';
	signal slwr   :  std_logic := '1';
	signal sloe   :  std_logic := '1';

	signal r_data	  :  std_logic_vector(DATA_WIDTH-1 downto 0)
		:= (others => '0');
	signal data		  :  unsigned(DATA_WIDTH-1 downto 0)
		:= (others => '0');

begin

	-- /OE control
oectrl:
	process (u_sloe, data)
	begin
		if u_sloe = '0' then
			u_fd <= (others => 'Z');
			u_fd <= std_logic_vector(resize(data, u_fd'length)) after T_OEON;
		else
			u_fd <= (others => 'Z') after T_OEOFF;
		end if;
	end process;


-- External C fifo simulation:
fifo_handler:
	process (u_ifclk)
	variable flags : fifoflag_t;
	variable d_data :  unsigned(DATA_WIDTH-1 downto 0);
	begin
		if rising_edge(u_ifclk) then
			if slrd = '0' then
				flags := "100000"; -- advance read pointer
			elsif slwr = '0' then
				flags := "010000"; -- advance write pointer
			else
				flags := "000000";
			end if;

			d_data := unsigned(u_fd(DATA_WIDTH-1 downto 0));
			fifo_io(d_data, flags);
			data <= d_data;
			-- Throttle simulation when FIFO is not active and Throttle
			-- bit set
			if flags(RXE) = '0' and throttle = '1' then
				usleep(50000);
			end if;

			can_rx <= flags(RXE);
			can_tx <= flags(TXF);

			fifo_flags <= flags;
		end if;
	end process;

	u_flag(TX_EMPTY) <= can_rx after T_XFLG;
	u_flag(RX_FULL)  <= can_tx after T_XFLG;

	-- Simulate setup timing for internal signals:
	sloe <= u_sloe after T_OEON;
	slrd <= u_slrd after T_SRD;
	slwr <= u_slwr after T_SRD;

end behaviour;
