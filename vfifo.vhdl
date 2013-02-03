--! \file vfifo.vhdl Virtualized FIFO implementation
--
-- (c) 2011-2013 Martin Strubel <hackfin@section5.ch>
--
-- Configureable WORDSIZE (1, 2)
--
-- This is the VirtualFIFO variant, but allows multiple instances
--

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.ghpi_netpp.all; -- For virtual register I/O (regmap_read())
	use work.ghpi_fifo.all;  -- For the FIFO definitions
-- use work.fpga_registers.all;    -- Register definitions

--! \brief A virtual FIFO component, accessible via netpp.vpi
--!
--! This virtual FIFO works like the VirtualFifo component (legacy), but
--! allows to be instanced more than once. It requires a netpp server to
--! run in order to be accessed from the outside. Typically, you include
--! this component into your simulation and run it with the
--! --vpi=netpp.vpi argument.
--! 
--! This FIFO component works full duplex, unlike the FX2 emulation.
--! A FIFO netpp property is simply a buffer that is read out or written
--! to, just that the internal handling is different from a DualPort16
--! virtual RAM, for example.
--! The default implementation of the FIFO property buffer reading is
--! blocking, that means, the call to dcDevice_GetProperty() will wait
--! until the requested data is ready. This can timeout under certain
--! circumstances, for example, when the simulation is very complex and
--! runs slow, such timeouts occur. In this case - and in general - it is
--! recommended to read the 'Fifo.InFill' property that contains the
--! number of available bytes in the FIFO. Likewise, 'Fifo.Outfill' can
--! be probed to see if there are still bytes left in the FIFO out buffer
--! to be read out by the simulation.
--!
--! A special feature is the throttle bit: Seen as 'Throttle' property
--! from outside, it will throttle the simulation when set and when no
--! FIFO activity is occuring. This helps to simulate fast FIFO throughputs
--! with no or little interruption on the VHDL simulation side.

entity VFIFO is
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
end entity;


architecture simulation of VFIFO is
constant TX_PROG : natural := 0;
constant TX_EMPTY : natural := 1;
constant RX_FULL : natural := 2;

constant DATA_WIDTH : natural := 8*WORDSIZE;

signal fifo_flags :  fifoflag_t := "000000";

signal throttle      : std_logic := '1';

shared variable fifo_handle : duplexfifo_t;

begin

process
	variable ret : integer;
begin
	fifo_handle := fifo_new(simulation'path_name, FIFOSIZE, WORDSIZE);
	if fifo_handle = null then
		assert false report "Failed to register FIFO";
	end if;
	wait_loop : loop
	  wait for 10 us;
	end loop wait_loop;
	fifo_del(fifo_handle);
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
		fifo_rxtx(fifo_handle, d_data, flags);
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

-- netpp_register:
-- 	process (clk)
-- 		variable val : unsigned(7 downto 0);
-- 	begin
-- 		if rising_edge(clk) then
-- 			regmap_read(R_Control, val);
-- 			throttle <= val(B_THROTTLE);
-- 		end if;
-- 	end process;

end simulation;
