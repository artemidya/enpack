<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
								xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
								xmlns:frmwrk="Corel Framework Data"
								exclude-result-prefixes="frmwrk">
	<xsl:output method="xml" encoding="UTF-8" indent="yes"/>
	<frmwrk:uiconfig>
		<frmwrk:applicationInfo name="CorelDRAW" framework="CorelDRAW" userConfiguration="true" />
	</frmwrk:uiconfig>

	<!-- Copy everything -->
	<xsl:template match="node()|@*">
		<xsl:copy>
			<xsl:apply-templates select="node()|@*"/>
		</xsl:copy>
	</xsl:template>

	<!-- Helper to insert a new item into a menu -->
	<xsl:template match="node()|@*" mode="insert-item">
		<xsl:param name="after"></xsl:param>
		<xsl:param name="before"></xsl:param>
		<xsl:param name="content"></xsl:param>
		<xsl:copy>
			<xsl:apply-templates select="@*"/>
			<xsl:for-each select="node()">
				<xsl:if test="name()='item' and @guidRef=$before">
					<xsl:copy-of select="$content"/>
				</xsl:if>
				<xsl:copy>
					<xsl:apply-templates select="node()|@*"/>
				</xsl:copy>
				<xsl:if test="name()='item' and @guidRef=$after">
					<xsl:copy-of select="$content"/>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="not(./item[@guidRef=$after]) and not(./item[@guidRef=$before])">
				<xsl:copy-of select="$content"/>
			</xsl:if>
		</xsl:copy>
	</xsl:template>

	<!-- Draw Adjust Main Menu -->
	<xsl:template match="//commandBarData[@guid='2cfa7035-cbef-4276-b686-adb4f77c80d6']/menu">
		<xsl:apply-templates mode="insert-item" select=".">
			<xsl:with-param name="after">f8179d03-81a7-47d7-8880-2f75cdef35fa</xsl:with-param>
			<xsl:with-param name="content">
				<xsl:if test="not(./item[@guidRef='b3a1c7e2-4f58-4d9b-a6e0-8c2f5d7e9b14'])">
					<item guidRef="b3a1c7e2-4f58-4d9b-a6e0-8c2f5d7e9b14"/>
				</xsl:if>
			</xsl:with-param>
		</xsl:apply-templates>
	</xsl:template>

	<!-- Bitmaps menu -->
	<xsl:template match="//commandBarData[@guid='4ddf79ec-25c9-4fcf-99a8-ff43845608dd']/menu">
		<xsl:apply-templates mode="insert-item" select=".">
			<xsl:with-param name="after">d207991b-8963-4bdf-84a1-ed936d466d20</xsl:with-param>
			<xsl:with-param name="content">
				<xsl:if test="not(./item[@guidRef='0258983a-8f06-417e-940f-b1cc012bab1e'])">
					<item guidRef="0258983a-8f06-417e-940f-b1cc012bab1e"/>
				</xsl:if>
				<xsl:if test="not(./item[@guidRef='726c629a-2055-4e0a-b8ae-7a1231b88d9c'])">
					<item guidRef="726c629a-2055-4e0a-b8ae-7a1231b88d9c"/>
				</xsl:if>
			</xsl:with-param>
		</xsl:apply-templates>
	</xsl:template>

	<!-- Trace Bitmap flyout / toolbar -->
	<xsl:template match="//commandBarData[@guid='A1C2DEBA-F628-4364-88F3-5DF2780EC98B']/menu | //commandBarData[@guid='A1C2DEBA-F628-4364-88F3-5DF2780EC98B']/toolbar">
		<xsl:apply-templates mode="insert-item" select=".">
			<xsl:with-param name="after">d207991b-8963-4bdf-84a1-ed936d466d20</xsl:with-param>
			<xsl:with-param name="content">
				<xsl:if test="not(./item[@guidRef='0258983a-8f06-417e-940f-b1cc012bab1e'])">
					<item guidRef="0258983a-8f06-417e-940f-b1cc012bab1e"/>
				</xsl:if>
				<xsl:if test="not(./item[@guidRef='726c629a-2055-4e0a-b8ae-7a1231b88d9c'])">
					<item guidRef="726c629a-2055-4e0a-b8ae-7a1231b88d9c"/>
				</xsl:if>
			</xsl:with-param>
		</xsl:apply-templates>
	</xsl:template>

	<!-- Commands to Append (bitmap context menu) -->
	<xsl:template match="//commandBarData[@guid='917340a7-4b31-4b20-9313-752a4ef09f0a']/menu">
		<xsl:apply-templates mode="insert-item" select=".">
			<xsl:with-param name="after">d207991b-8963-4bdf-84a1-ed936d466d20</xsl:with-param>
			<xsl:with-param name="content">
				<xsl:if test="not(./item[@guidRef='0258983a-8f06-417e-940f-b1cc012bab1e'])">
					<item guidRef="0258983a-8f06-417e-940f-b1cc012bab1e"/>
				</xsl:if>
				<xsl:if test="not(./item[@guidRef='726c629a-2055-4e0a-b8ae-7a1231b88d9c'])">
					<item guidRef="726c629a-2055-4e0a-b8ae-7a1231b88d9c"/>
				</xsl:if>
			</xsl:with-param>
		</xsl:apply-templates>
	</xsl:template>

	<!-- Help menu: Advanced Account Settings (inserted after Corel Support) -->
	<xsl:template match="//commandBarData[@guid='3a97999f-e1e6-4222-8168-873c504cdc02']/menu">
		<xsl:apply-templates mode="insert-item" select=".">
			<xsl:with-param name="after">5c57ab14-92b3-445d-8e08-93c9853db546</xsl:with-param>
			<xsl:with-param name="content">
				<xsl:if test="not(./item[@guidRef='52bd0964-19b0-4cd3-8c88-bfc1254b2069'])">
					<item guidRef="52bd0964-19b0-4cd3-8c88-bfc1254b2069"/>
				</xsl:if>
			</xsl:with-param>
		</xsl:apply-templates>
	</xsl:template>

	<!-- AI Generate flyout: Create Vector shortcuts -->
	<xsl:template match="//commandBarData[@guid='ac756ad6-84d9-43f5-a5f1-183aa81c6870']/menu | //commandBarData[@guid='ac756ad6-84d9-43f5-a5f1-183aa81c6870']/toolbar">
		<xsl:apply-templates mode="insert-item" select=".">
			<xsl:with-param name="before">4bf3be7a-cdd1-40a7-84ae-448ad787cc07</xsl:with-param>
			<xsl:with-param name="content">
				<xsl:if test="not(./item[@guidRef='9c0ccd48-7a5f-43c7-aff0-f59be1bb1595'])">
					<item guidRef="9c0ccd48-7a5f-43c7-aff0-f59be1bb1595"/>
				</xsl:if>
				<xsl:if test="not(./item[@guidRef='a0776aad-7c8b-499b-8e67-df3801bf1769'])">
					<item guidRef="a0776aad-7c8b-499b-8e67-df3801bf1769"/>
				</xsl:if>
			</xsl:with-param>
		</xsl:apply-templates>
	</xsl:template>
</xsl:stylesheet>