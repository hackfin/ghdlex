-- Virtual FIFO
--
-- Virtualized FIFO implementation
--
-- (c) 2011, 2012 Martin Strubel <hackfin@section5.ch>
--
-- Configureable WORDSIZE (1, 2)
--
--
-- Unlike the CFIFO implementation, this allows full duplex (simultaneous) I/O
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ghdlex;
use ghdlex.ghpi_fifo.all;
use ghdlex.ghpi_netpp.all; -- For virtual register I/O (regmap_read())
use ghdlex.ghdlsim.all;    -- Register definitions

library work;
use work.fifoemu.all;

entity VirtualFIFO is
	generic (
		WORDSIZE : natural := 1
	);
	port (
		signal clk         : in  std_logic;
		signal wr_ready    : out std_logic;
		signal rd_ready    : out std_logic;
		signal wr_enable   : in  std_logic;
		signal rd_enable   : in  std_logic;
		signal data_in     : out std_logic_vector(8*WORDSIZE-1 downto 0);
		signal data_out    : in  std_logic_vector(8*WORDSIZE-1 downto 0)

	);
end entity;

architecture behaviour of VirtualFIFO is
	constant TX_PROG : natural := 0;
	constant TX_EMPTY : natural := 1;
	constant RX_FULL : natural := 2;

	constant DATA_WIDTH : natural := 8*WORDSIZE;

	signal fifo_flags :  fifoflag_t := "000000";

	signal throttle      : std_logic := '1';

begin

	process
		variable ret : integer;
	begin
		ret := fifo_thread_init("", WORDSIZE);
		-- print(output, "Init thread");
		wait_loop : loop
		  wait for 10 us;
		  if fifo_terminate then
		  	exit;
		  end if;
		end loop wait_loop;
		fifo_thread_exit;
		-- print(output, "Terminated clk process");
		wait;
	end process;

-- External C fifo simulation:
fifo_handler:
	process (clk)
	variable flags : fifoflag_t;
	variable d_data :  unsigned(DATA_WIDTH-1 downto 0);
	begin
		if rising_edge(clk) then
			flags := rd_enable & wr_enable & "0000";
			d_data := unsigned(data_out(DATA_WIDTH-1 downto 0));
			fifo_io(d_data, flags);
			data_in <= std_logic_vector(d_data(DATA_WIDTH-1 downto 0));
			-- Throttle simulation when FIFO is not active and Throttle
			-- bit set
			if flags(RXE) = '0' and throttle = '1' then
				usleep(50000);
			end if;

			rd_ready <= flags(RXE);
			wr_ready <= flags(TXF);

			fifo_flags <= flags;
		end if;
	end process;

netpp_register:
	process (clk)
		variable val : unsigned(7 downto 0);
	begin
		if rising_edge(clk) then
			regmap_read(R_Control, val);
			throttle <= val(B_THROTTLE);
		end if;
	end process;

end behaviour;
