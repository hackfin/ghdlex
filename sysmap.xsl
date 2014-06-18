<?xml version="1.0" encoding="ISO-8859-1"?>
<!-- (c) 2007-2014 Martin Strubel <hackfin@section5.ch>
     This file converts a XML device description into VHDL a SoC system map

     This file is under GPLv2 license. Dual licensing models are possible, as
     long as no third party is involved.
-->
<xsl:stylesheet version="1.0" 
	xmlns:my="http://www.section5.ch/dclib/schema/devdesc"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >
<xsl:import href="map.xsl"/>	
<xsl:import href="vhdlport.xsl"/>	

<!-- Output method TEXT -->
	<xsl:output method="text" indent="yes" encoding="ISO-8859-1"/>	

<!-- Source file name -->
<xsl:param name="srcfile">"-UNKNOWN-"</xsl:param>
<!-- Index of desired device -->
<xsl:param name="selectDevice">1</xsl:param>
<!-- Entity prefix -->
<xsl:param name="entprefix">mmr</xsl:param>
<!-- Decoder prefix -->
<xsl:param name="decoderprefix">decode_</xsl:param>
<!-- Interface type (std_logic_vector or unsigned) -->
<xsl:param name="iface_type">std_logic_vector</xsl:param>
<!-- Data bus width -->
<xsl:param name="dwidth">16</xsl:param>

<xsl:variable name="index" select="number($selectDevice)"></xsl:variable>

<xsl:template match="my:group/my:property" mode="unit_map">
	-- Property <xsl:value-of select="../@name"/>::<xsl:value-of select="@name"/>
</xsl:template>


<xsl:template match="my:item" mode="unit_map">
<xsl:text>	constant SELECT_</xsl:text><xsl:value-of select="@name"/> : integer := <xsl:value-of select="my:value"/>;
	signal   ce_<xsl:value-of select="@name"/> : std_logic;
</xsl:template>



<xsl:template match="my:array" mode="decl_signals">
	-- <xsl:value-of select="@name"/> signals
	type <xsl:value-of select="@name"/>_wp_array is array
		(integer range 0 to <xsl:value-of select="my:size/my:value"/>) of
			<xsl:value-of select="@name"/>_WritePort;
	type <xsl:value-of select="@name"/>_rp_array is array
		(integer range 0 to <xsl:value-of select="my:size/my:value"/>) of
			<xsl:value-of select="@name"/>_ReadPort;

	signal ce_dev_<xsl:value-of select="@name"/> : std_logic_vector(<xsl:value-of select="my:size/my:value"/> downto 0);
	signal <xsl:value-of select="@name"/>_ctrl : <xsl:value-of select="@name"/>_wp_array;
	signal <xsl:value-of select="@name"/>_stat : <xsl:value-of select="@name"/>_rp_array;
	type <xsl:value-of select="@name"/>_dout_ar_t is array
		(integer range 0 to <xsl:value-of select="my:size/my:value"/>) of
		pio_data_<xsl:value-of select="@name"/>_t;
	signal data_out_<xsl:value-of select="@name"/> : <xsl:value-of select="@name"/>_dout_ar_t;
	signal devindex_<xsl:value-of select="@name"/> : integer;
</xsl:template>

<xsl:template match="my:array" mode="unit_instance">

	devindex_<xsl:value-of select="@name"/> &lt;= to_integer(wb_in.adr(BV_MMR_SELECT_DEVINDEX_<xsl:value-of select="@name"/>));

<xsl:value-of select="@name"/>_multi:
	------ Instanciate multiple units of <xsl:value-of select="@name"/> ------
	for i in 0 to <xsl:value-of select="my:size/my:value"/> generate
	ce_dev_<xsl:value-of select="@name"/>(i) &lt;= ce_<xsl:value-of select="@name"/> when i = devindex_<xsl:value-of select="@name"/> else '0';
	<xsl:apply-templates select=".//my:property" mode="multi_unit_instance" />
	<xsl:apply-templates select=".//my:property" mode="multi_dev_instance" />
	end generate;
	----------------------------------
</xsl:template>

<xsl:template match="my:array" mode="dataout_mux">
			data_out_<xsl:value-of select="@name"/>(devindex_<xsl:value-of select="@name"/>) when SELECT_<xsl:value-of select="@name"/>,
</xsl:template>

<xsl:template match="my:property" mode="decl_signals">
	-- <xsl:value-of select="@name"/> signals {
	signal <xsl:value-of select="@name"/>_ctrl : <xsl:value-of select="@name"/>_WritePort;
	-- Initialize this one for sane simulation:
	signal data_out_<xsl:value-of select="@name"/> : pio_data_t := (others => '0');
	signal <xsl:value-of select="@name"/>_stat : <xsl:value-of select="@name"/>_ReadPort;
	-- }
</xsl:template>

<xsl:template match="my:property" mode="dataout_mux">
			data_out_<xsl:value-of select="@name"/> when SELECT_<xsl:value-of select="@name"/>,
</xsl:template>

<xsl:template match="my:property" mode="gen_select">
	ce_<xsl:value-of select="@name"/> &lt;= ce when perio_select = SELECT_
</xsl:template>

<xsl:template match="my:bitfield" mode="assign_ports">
	<xsl:param name="index"></xsl:param>

	<xsl:text>		</xsl:text>
	<xsl:value-of select="@name"/> =&gt; <xsl:value-of select="../@id"/>_<xsl:value-of select="@name"/><xsl:value-of select="$index"/>,
</xsl:template>

<xsl:template match="my:register" mode="assign_ports">
	<xsl:param name="index"></xsl:param>
	<xsl:choose>
		<xsl:when test="./my:bitfield">
		-- Assign ports for Register <xsl:value-of select="@id"/><xsl:text>
</xsl:text>
		<xsl:apply-templates select="my:bitfield" mode="assign_ports">
			<xsl:with-param name="index" select="$index"/>
		</xsl:apply-templates>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text>		</xsl:text>
			<xsl:value-of select="@id"/> =&gt; <xsl:value-of select="@id"/>,
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="my:regref" mode="assign_ports">
	<xsl:choose>
		<xsl:when test="../../my:size"><!-- If we are parented by an array -->
			<xsl:apply-templates select="key('regkey', @ref)" mode="assign_ports">
				<xsl:with-param name="index">(i)</xsl:with-param>
			</xsl:apply-templates>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="key('regkey', @ref)" mode="assign_ports" />
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="my:property" mode="multi_unit_instance">
inst_<xsl:value-of select="../@name"/>_decoder:
	<xsl:value-of select="$decoderprefix"/><xsl:value-of select="../@name"/>
	port map (
		ce        =&gt; ce_dev_<xsl:value-of select="../@name"/>(i),
		ctrl      =&gt; <xsl:value-of select="../@name"/>_ctrl(i),
		stat      =&gt; <xsl:value-of select="../@name"/>_stat(i),
		data_in   =&gt; wb_in.dat(DATA_SLICE_<xsl:value-of select="../@name"/>),
		data_out  =&gt; data_out_<xsl:value-of select="../@name"/>(DATA_SLICE_<xsl:value-of select="../@name"/>)(i),
		addr      =&gt; wb_in.adr(BV_MMR_CFG_<xsl:value-of select="../@name"/>),
		we        =&gt; wb_in.we,
		clk       =&gt; clk
	);
</xsl:template>

<xsl:template match="my:property" mode="multi_dev_instance">
	<xsl:if test="my:info">-- <xsl:value-of select="my:info"/></xsl:if>
inst_dev_<xsl:value-of select="../@name"/>:
	entity work.<xsl:value-of select="../@name"/>_core
	port map (
		-- Generated ports:
<xsl:apply-templates select="my:regref" mode="assign_ports" />
		ctrl      =&gt; <xsl:value-of select="../@name"/>_ctrl(i),
		stat      =&gt; <xsl:value-of select="../@name"/>_stat(i),
		clk       =&gt; clk
	);
</xsl:template>

<xsl:template match="my:property" mode="dev_instance">
	<xsl:text>
</xsl:text>
	<xsl:if test="my:info">-- <xsl:value-of select="my:info"/></xsl:if>
inst_dev_<xsl:value-of select="@name"/>:
	entity work.<xsl:value-of select="@name"/>_core
	port map (
<xsl:apply-templates select="my:regref" mode="assign_ports" />
		-- Default control ports:
		ctrl      =&gt; <xsl:value-of select="@name"/>_ctrl,
		stat      =&gt; <xsl:value-of select="@name"/>_stat,
		clk       =&gt; clk
	);
</xsl:template>

<xsl:template match="my:property" mode="unit_instance">
inst_<xsl:value-of select="@name"/>_decoder:
	<xsl:value-of select="$decoderprefix"/><xsl:value-of select="@name"/>
	port map (
		ce        =&gt; ce_<xsl:value-of select="@name"/>,
		ctrl      =&gt; <xsl:value-of select="@name"/>_ctrl,
		stat      =&gt; <xsl:value-of select="@name"/>_stat,
		data_in   =&gt; wb_in.dat(DATA_SLICE_<xsl:value-of select="@name"/>),
		data_out  =&gt; data_out_<xsl:value-of select="@name"/>(DATA_SLICE_<xsl:value-of select="@name"/>),
		addr      =&gt; wb_in.adr(BV_MMR_CFG_<xsl:value-of select="@name"/>),
		we        =&gt; wb_in.we,
		clk       =&gt; clk
	);
</xsl:template>



<xsl:template match="/">
<xsl:variable name="entityname">perio</xsl:variable>
-- This is a VHDL template file generated from
-- <xsl:value-of select="$srcfile"/>
-- using sysmap.xsl
-- Changes to this file WILL BE LOST. Edit the source file.
--
-- (c) 2012-2013, Martin Strubel // hackfin@section5.ch
--
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
--  System map definitions:
	use work.system_map.all;

entity <xsl:value-of select="$entprefix"/>_<xsl:value-of select="$entityname"/> is
	port (
		-- CPU side:
		wb_in     : in wb_WritePort;
		wb_out    : out wb_ReadPort;
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:property" mode="signal_export" />
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:array" mode="signal_export" />
		ce        : in std_logic;
		clk       : in std_logic
	);
end entity <xsl:value-of select="$entprefix"/>_<xsl:value-of select="$entityname" />;


architecture behaviour of <xsl:value-of select="$entprefix"/>_<xsl:value-of select="$entityname"/> is
	-- Constants for data widths:
<xsl:apply-templates select=".//my:registermap[not(@nodecode='true') and not(@hidden='true')]" mode="decl_dwidths" />
	-- General data bus with width <xsl:value-of select="$dwidth"/>
	subtype pio_data_t is <xsl:value-of select="$iface_type"/>(<xsl:value-of select="$dwidth"/>-1 downto 0);

	-- Unit selection constants / chip enable signals:
<xsl:apply-templates select=".//my:group[@name='UNIT_MAP']/my:property/my:choice/my:item" mode="unit_map" />

<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:array" mode="decl_signals" />
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:property" mode="decl_signals" />

	signal bus_select : integer;
	alias perio_unit : <xsl:value-of select="$iface_type"/>(BV_MMR_SELECT_perio) is
		wb_in.adr(BV_MMR_SELECT_perio);
begin

	-- Unit selection signals:
<xsl:apply-templates select=".//my:group[@name='UNIT_MAP']/my:property/my:choice/my:item" mode="perio_select" />

	-- Bus assignment:
delay:
	process (clk)
	begin
		if rising_edge(clk) then
			bus_select &lt;= to_integer(perio_unit);
		end if;
	end process;

	-- wb_out &lt;= wbout_unit(bus_select)
	with bus_select select wb_out.dat &lt;=
		<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:property" mode="dataout_mux" />
		<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:array" mode="dataout_mux" />
		(others => '0') when others;

----------------------------------------------------------------------------
-- Single unit instanciation:

----------------------------------------------------------------------------
-- Decoders:
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:property" mode="unit_instance" />

----------------------------------------------------------------------------
-- Device controllers:
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:property" mode="dev_instance" />

----------------------------------------------------------------------------
-- Multiple unit instanciation
<xsl:apply-templates select=".//my:group[@name='INSTANCES']/my:array" mode="unit_instance" />

end architecture;

</xsl:template>

</xsl:stylesheet>
