<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet version="1.0" 
	xmlns:my="http://www.section5.ch/dclib/schema/devdesc"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

	<xsl:output method="text" encoding="ISO-8859-1"/>	

<!-- Source file name -->
<xsl:param name="srcfile">"-UNKNOWN-"</xsl:param>
<!-- Index of desired device -->
<xsl:param name="selectDevice">1</xsl:param>
<!-- If 1, use parent register map's name as prefix -->
<xsl:param name="useMapPrefix">0</xsl:param>
<!-- Register prefix -->
<xsl:param name="regprefix">R_</xsl:param>
<!-- most significant byte to define address width -->
<xsl:param name="msb">7</xsl:param>


<xsl:template match="my:header">
<xsl:if test="@language = 'VHDL'">
<xsl:value-of select="."/>
</xsl:if>
</xsl:template>

	<!-- Register definition/declaration and reference -->

	<xsl:template match="my:registermap" mode="reg_decl">
-------------------------------------------------------------------------
-- Address segment '<xsl:value-of select="@name"/>'
--         Offset: <xsl:value-of select="@offset"/>

<xsl:apply-templates select=".//my:register" mode="reg_decl"/>
	</xsl:template>
<!-- bitfield -->
	<xsl:template match="my:bitfield" mode="reg_decl">
<xsl:if test="./my:info">    -- <xsl:value-of select="./my:info"/></xsl:if>
<xsl:choose>
<xsl:when test="@msb = @lsb">
<xsl:text>
	</xsl:text>constant <xsl:value-of select="substring(concat(@id, '            '), 1, 12)"/><xsl:text> B_</xsl:text><xsl:value-of select="@name"/> : natural := <xsl:value-of select="@msb"/>;</xsl:when>
<xsl:otherwise>
<xsl:text>
	</xsl:text>subtype  <xsl:value-of select="substring(concat(@id, '             '), 1, 12)"/><xsl:text> BV_</xsl:text><xsl:value-of select="@name"/> is integer range <xsl:value-of select="@msb"/> downto <xsl:value-of select="@lsb"/>;
</xsl:otherwise>
</xsl:choose>
</xsl:template>
<!-- register -->
	<xsl:template match="my:register" mode="reg_decl">
<xsl:if test="./my:info">-- <xsl:value-of select="./my:info"/></xsl:if>
	constant <xsl:value-of select="$regprefix"/>
<xsl:if test="$useMapPrefix = 1"><xsl:value-of select="../@name"/>_</xsl:if><xsl:value-of select="substring(concat(@id, '                '), 1, 16)"/><xsl:text> </xsl:text> : regaddr_t := x"<xsl:value-of select="substring(@addr, 3, 4)"/>";
<xsl:apply-templates select="./my:bitfield" mode="reg_decl"/></xsl:template>
<xsl:template match="/">--
-- This is a VHDL package file generated from <xsl:value-of select="$srcfile"/>
-- using vhdlregs.xsl
-- Changes to this file WILL BE LOST. Edit the source file.
--
-- Implements a 'msb+1' bit address wide register map as VHDL package
--
-- Set the msb by specifying the --param msb `number` option to xsltproc
--
-- (c) 2007-2011, Martin Strubel // hackfin@section5.ch
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

<xsl:apply-templates select=".//my:header"/>

<xsl:variable name="index" select="number($selectDevice)"></xsl:variable>

package <xsl:value-of select="my:devdesc/my:device[$index]/my:registermap/@id"/> is
	subtype regaddr_t is unsigned(<xsl:value-of select="$msb"/> downto 0);
	subtype BYTESLICE is integer range 7 downto 0;

<xsl:apply-templates select="my:devdesc/my:device[$index]/my:registermap" mode="reg_decl"/>

end <xsl:value-of select="my:devdesc/my:device[$index]/my:registermap/@id"/>;

<xsl:text>
</xsl:text>
</xsl:template>


</xsl:stylesheet>

