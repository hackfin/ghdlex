--! \file libfifo.vhdl      I/O interface for thread controlled FIFO
-- (c) 2011, Martin Strubel <hackfin@section5.ch>
--

--! \deprecated DO NOT USE THIS API ANYMORE.
--! Use the FIFO API from libnetpp.chdl.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Unsigned

--! \brief VHDL FIFO interface
--!
--! Simple virtual FIFO module
--! Implements a first-fall-through FIFO accessible through network
--! via the netpp library.
--! Either the VirtualFIFO component can be integrated into the design,
--! or the FIFO functions can be called on a lower level.
--! The data in/out word size is configureable using the WORD_SIZE generic.
--! (Supported values: 1, 2)
--!
--! \example virtualfifo.vhdl
--!
--! \defgroup GHPI_Fifo   VHDL FIFO interface
--! \addtogroup GHPI_Fifo
--! \{
package ghpi_fifo is

	--! Set this variable to true to terminate FIFO thread
	shared variable fifo_terminate : boolean := false;

	subtype fdata is unsigned;
	subtype fifoflag_t is unsigned(0 to 5);
	-- FIFO flag indices:
	constant RX  : natural := 0; --! in: Read advance, out: FIFO not empty
	constant TX  : natural := 1; --! in: Write advance, out: FIFO not full
	constant RXE : natural := 2; --! out: LOW when FIFO almost not empty
	constant TXF : natural := 3; --! out: LOW when FIFO almost full
	constant OVR : natural := 4; --! out: overrun bit. Write 1 to clear.
	constant UNR : natural := 5; --! out: underrun bit. W1C.

	--! Init the external FIFO thread
	--! \param arg    Currently an empty string, unused.
	--! \param wsize  1: Word size 8 bits, 2: 16 bits
	function fifo_thread_init(arg: string; wsize: integer) return integer;

	-- This is just a wrapper for the above function
	function sim_fifo_thread_init(arg: string; wsize: integer) return integer;
	attribute foreign of sim_fifo_thread_init :
		function is "VHPIDIRECT sim_fifo_thread_init";

	--! Shutdown external FIFO thread
	procedure fifo_thread_exit;
	attribute foreign of fifo_thread_exit : procedure is "VHPIDIRECT fifo_thread_exit";

	--! The FIFO I/O routine.
	--! \param data   Pointer to data being written, if TX flag set,
	--!               Data is modified with the 'read' FIFO data when RX
	--!               flag set. If FIFO is not ready for READ or WRITE
	--!               operation (empty or full), an underrun respective
	--!               overrun condition will occur and be signalled in the
	--!               flags(OVR) and flags(UNR) bits. Clearing this error
	--!               condition is achieved by setting these error flags to
	--!               '1'.
	--!               The word size of the data bit vector is defined by
	--!               the wsize argument to fifo_thread_init()
	--! \param flags  The FIFO control (in) and status (out) flags.
	--!               When calling this function the first time, you should
	--!               check the status by setting all flags to '0'.
	--!               On return, the (RX) and (TX) fill state can be read
	--!               from the RXE and TXF flags (for burst reading) and
	--!               from the RX and TX flags (current, absolute FIFO fill
	--!               state. On subsequent calls, the RX and TX flags
	--!               indicate, which action (Read word/Write word) should
	--!               be taken. The current status is always returned in the
	--!               flags array.
	procedure fifo_io(
		data: inout fdata;
		flags : inout fifoflag_t
	);
	attribute foreign of fifo_io : procedure is
		"VHPIDIRECT sim_fifo_io";

	-- FLAG assignments for FX2 emulation
	constant TX_PROG  : natural := 0;
	constant TX_EMPTY : natural := 1;
	constant RX_FULL  : natural := 2;

	component VirtualFIFO is
		generic (
			WORDSIZE : natural := 1
		);
		port (
			signal clk         : in  std_logic;
			signal wr_ready    : out std_logic;
			signal rd_ready    : out std_logic;
			signal wr_enable   : in  std_logic;
			signal rd_enable   : in  std_logic;
			signal data_out    : in  std_logic_vector(8*WORDSIZE-1 downto 0);
			signal data_in     : out std_logic_vector(8*WORDSIZE-1 downto 0)
		);
	end component;

end package;

--! \}

package body ghpi_fifo is
	function fifo_thread_init(arg: string; wsize: integer)
	return integer is begin
		return sim_fifo_thread_init(arg & NUL, wsize);
	end fifo_thread_init;

	function sim_fifo_thread_init(arg: string; wsize: integer)
	return integer is begin
		assert false report "VHPI" severity failure;
	end sim_fifo_thread_init;

	procedure fifo_thread_exit is begin
		assert false report "VHPI" severity failure;
	end fifo_thread_exit;

	procedure fifo_io(
		data:  inout fdata;
		flags: inout fifoflag_t
	) is
	begin
		assert false report "VHPI" severity failure;
	end fifo_io;

end package body;

