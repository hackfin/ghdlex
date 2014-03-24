<?xml version="1.0" encoding="ISO-8859-1"?>
<!-- (c) 2007-2014 Martin Strubel <hackfin@section5.ch>
     This file converts a XML device description into VHDL.

     This file is under GPLv2 license. Dual licensing models are possible, as
     long as no third party is involved.
-->
<xsl:stylesheet version="1.0" 
	xmlns:my="http://www.section5.ch/dclib/schema/devdesc"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >
<xsl:import href="map.xsl"/>	

	<xsl:output method="text" encoding="ISO-8859-1"/>	


<!-- Source file name -->
<xsl:param name="srcfile">"-UNKNOWN-"</xsl:param>
<!-- Index of desired device -->
<xsl:param name="selectDevice">1</xsl:param>
<!-- If 1, use parent register map's name as prefix -->
<xsl:param name="useMapPrefix">0</xsl:param>
<!-- Register prefix -->
<xsl:param name="regprefix">R_</xsl:param>
<!-- Entity prefix -->
<xsl:param name="entprefix">decode</xsl:param>
<!-- most significant byte to define address width -->
<xsl:param name="msb">7</xsl:param>

<xsl:param name="output_decoder">0</xsl:param>
<xsl:param name="dwidth">16</xsl:param>

<xsl:template match="my:header">
<xsl:if test="@language = 'VHDL'">
<xsl:value-of select="."/>
</xsl:if>
</xsl:template>

	<!-- Register definition/declaration and reference -->

<xsl:template match="my:registermap" mode="reg_record">
<!-- HACK: If registermap has id soc_mmr, do not emit -->
<xsl:if test="not(@id='soc_mmr') and not(@nodecode='true')">
<xsl:if test="./my:register[@access='RO']">
	type <xsl:value-of select="@id"/>_ReadPort is record
<xsl:apply-templates select=".//my:register[@access='RO']" mode="reg_record"/>
<xsl:text>	end record;
</xsl:text>
</xsl:if>
<xsl:if test="./my:register[not(@access) or @access='RW' or @access='WO']">
	type <xsl:value-of select="@id"/>_WritePort is record
<xsl:apply-templates select=".//my:register[not(@access='RO') or not(@access) or @access='RW']" mode="reg_record"/>
<xsl:apply-templates select=".//my:register[@volatile='true']" mode="reg_notify"/>
<xsl:text>	end record;
</xsl:text>
</xsl:if>
</xsl:if>
</xsl:template>

<xsl:template match="my:registermap" mode="reg_decl">
-------------------------------------------------------------------------
-- Address segment '<xsl:value-of select="@name"/>'
--         Offset: <xsl:value-of select="@offset"/>
	<xsl:text>

</xsl:text>
	<xsl:apply-templates select=".//my:register" mode="reg_decl"/>
</xsl:template>

<xsl:template match="my:registermap" mode="comp_decl">
<xsl:if test="not(@id='soc_mmr') and not(@nodecode='true')">

---------------------------------------------------------
-- Decoder unit for '<xsl:value-of select="@name"/>'

component <xsl:value-of select="$entprefix"/>_<xsl:value-of select="@id"/> is
	port (
		ce        : in  std_logic;
		ctrl      : out <xsl:value-of select="@id"/>_WritePort;
		stat      : in  <xsl:value-of select="@id"/>_ReadPort;
		data_in   : in  std_logic_vector(<xsl:value-of select="$dwidth"/>-1 downto 0);
		data_out  : out std_logic_vector(<xsl:value-of select="$dwidth"/>-1 downto 0);
		addr      : in  std_logic_vector(BV_MMR_CFG_<xsl:value-of select="@id"/>);
		we        : in  std_logic;
		clk       : in  std_logic
	);
end component <xsl:value-of select="$entprefix"/>_<xsl:value-of select="@id" />;
</xsl:if>
</xsl:template>

<!-- bitfield -->
<xsl:template match="my:bitfield" mode="reg_record">

	<xsl:text>		--! Exported value for bit (vector) '</xsl:text>
	<xsl:value-of select="@name"/>
	<xsl:text>'
</xsl:text>

	<xsl:choose>
		<xsl:when test="@msb = @lsb">
			<xsl:text>		</xsl:text><xsl:value-of select="translate(@name, $ucase, $lcase)"/>
			<xsl:text> : std_logic;
</xsl:text>

		</xsl:when>
		<xsl:otherwise>
			<xsl:text>		</xsl:text><xsl:value-of select="translate(@name, $ucase, $lcase)"/> : std_logic_vector(BV_<xsl:value-of select="@name"/>
			<xsl:text>);
</xsl:text>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template name="emit_info">
<xsl:if test="./my:info">-- <xsl:value-of select="normalize-space(./my:info)"/>
	<xsl:text>
</xsl:text>
</xsl:if>
</xsl:template>


<xsl:template match="my:bitfield" mode="reg_decl">
<xsl:call-template name="emit_info"/>
	<xsl:choose>
		<xsl:when test="@msb = @lsb">
			<xsl:text>	constant </xsl:text><xsl:value-of select="substring(concat(@id, '            '), 1, 12)"/><xsl:text> B_</xsl:text><xsl:value-of select="@name"/> : natural := <xsl:value-of select="@msb"/>
			<xsl:text>;
</xsl:text>
		</xsl:when>
		<xsl:otherwise>
			<xsl:text>	subtype  </xsl:text>
			<xsl:value-of select="substring(concat(@id, '             '), 1, 12)"/>
			<xsl:text> BV_</xsl:text>
			<xsl:value-of select="@name"/> is integer range <xsl:value-of select="@msb"/> downto <xsl:value-of select="@lsb"/>
			<xsl:text>;
</xsl:text>

		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- register -->
<xsl:template match="my:register" mode="reg_record">
	<xsl:param name="regid"><xsl:value-of select="translate(@id, $ucase, $lcase)"/></xsl:param>

	<xsl:if test="not(@hidden='1')">

	<xsl:text>		--! Exported value for register '</xsl:text>
	<xsl:value-of select="$regprefix"/>
	<xsl:if test="$useMapPrefix = 1"><xsl:value-of select="../@name"/>_</xsl:if>
	<xsl:value-of select="@id"/>
	<xsl:text>'
</xsl:text>

	<xsl:choose>
		<xsl:when test="./my:bitfield">
			<xsl:apply-templates select=".//my:bitfield" mode="reg_record"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:choose>
				<xsl:when test="@size">
					<xsl:text>		</xsl:text>
					<xsl:value-of select="$regid"/> : std_logic_vector(REG_SIZE<xsl:value-of select="@size"/>B);
</xsl:when>
				<xsl:otherwise>
					<xsl:text>		</xsl:text>
					<xsl:value-of select="$regid"/> : std_logic_vector(REG_SIZE);
</xsl:otherwise>
			</xsl:choose>
		</xsl:otherwise>
	</xsl:choose>
	</xsl:if>
</xsl:template>

<!-- Notify signal, when volatile register was accessed -->
<xsl:template match="my:register" mode="reg_notify">
	<xsl:text>		--! Notify access of Register '</xsl:text>
	<xsl:value-of select="@id"/><xsl:text>'
		select_</xsl:text>
	<xsl:value-of select="translate(@id, $ucase, $lcase)"/> : std_logic;
</xsl:template>


<xsl:template match="my:register" mode="reg_decl">
<xsl:call-template name="emit_info"/>
	<xsl:text>	constant </xsl:text>
	<xsl:value-of select="$regprefix"/>
	<xsl:if test="$useMapPrefix = 1"><xsl:value-of select="../@name"/>_</xsl:if>
	<xsl:value-of select="substring(concat(@id, '                '), 1, 16)"/>
	<xsl:text> </xsl:text> : regaddr_t := x"<xsl:value-of select="substring(@addr, 3, 4)"/>
	<xsl:text>";
</xsl:text>
	<xsl:apply-templates select="./my:bitfield" mode="reg_decl"/>
</xsl:template>

<xsl:template match="/">--
-- This is a VHDL package file generated from <xsl:value-of select="$srcfile"/>
-- using vhdlregs.xsl
-- Changes to this file WILL BE LOST. Edit the source file.
--
-- Implements a 'msb+1' bit address wide register map as VHDL package
--
-- Set the msb by specifying the --param msb `number` option to xsltproc
--
-- (c) 2007-2014, Martin Strubel // hackfin@section5.ch
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

<xsl:apply-templates select=".//my:header"/>

<xsl:variable name="index" select="number($selectDevice)"></xsl:variable>

package <xsl:value-of select="my:devdesc/my:device[$index]/@id"/> is
	subtype  regaddr_t is unsigned(<xsl:value-of select="$msb"/> downto 0);

	subtype  REG_SIZE1B is integer range 7 downto 0;
	subtype  REG_SIZE2B is integer range 15 downto 0;
	subtype  REG_SIZE3B is integer range 23 downto 0;
	subtype  REG_SIZE4B is integer range 31 downto 0;


<xsl:apply-templates select="my:devdesc/my:device[$index]/my:registermap" mode="reg_decl"/>

	-- Access records:
<xsl:apply-templates select="my:devdesc/my:device[$index]/my:registermap[not(@hidden='true')]" mode="reg_record"/>

<xsl:if test="$output_decoder=1">
	-- Decoder components:
<xsl:apply-templates select="my:devdesc/my:device[$index]/my:registermap[not(@hidden='true')]" mode="comp_decl"/>
</xsl:if>

end <xsl:value-of select="my:devdesc/my:device[$index]/@id"/>;

<xsl:text>
</xsl:text>
</xsl:template>


</xsl:stylesheet>

