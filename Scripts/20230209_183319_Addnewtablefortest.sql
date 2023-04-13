/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE [bodb_N88]
GO
/*
	Created: 20230209@Malcolm
	DB: DBN88-bodb_N88
	Task: Create new table [RedmineID: #183319]
*/

CREATE TABLE [dbo].[DepositInfoTest](
	[DepositId] [int] NOT NULL,
	[TransId] [varchar](30) NULL,
	[DepositType] [tinyint] NULL,
	[CustId] [int] NULL,
	[UserName] [varchar](30) NULL,
	[CurrencyId] [tinyint] NULL,
	[SiteId] [int] NULL,
	[DepositInfo] [nvarchar](max) NULL,
	[Amount] [decimal](18, 4) NULL,
	[ActualDeposit] [decimal](18, 4) NULL,
	[CreateTime] [datetime] NULL,
	[TPCreateTime] [datetime] NULL,
	[CallbackTime] [datetime] NULL,
	[FirstDeposit] [bit] NULL,
	[ThirdId] [varchar](100) NULL,
	[RefId] [varchar](100) NULL,
	[DepositTime] [datetime] NULL,
	[Memo] [varchar](100) NULL,
	[PostScript] [varchar](45) NULL,
	[Comment] [varchar](500) NULL,
	[Status] [tinyint] NULL,
	[WinlostDate]  AS (CONVERT([date],[CreateTime],0)),
	[Flag] [int] NULL,
	[Operator] [varchar](30) NULL,
	[UpdateTime] [datetime] NULL,
 CONSTRAINT [PK_DepositInfoTest] PRIMARY KEY NONCLUSTERED 
 (
	[DepositId] ASC
 ) ON [ReportData]
) ON [ReportData] TEXTIMAGE_ON [ReportData]
GO

CREATE CLUSTERED INDEX [CIX_DepositInfoTest] ON [dbo].[DepositInfoTest]
(
	[WinlostDate] ASC
) ON [ReportData]
GO

CREATE NONCLUSTERED INDEX [IX_RPT_WL_DepositTest] ON [dbo].[DepositInfoTest]
(
	[Status] ASC,
	[CreateTime] ASC,
	[WinlostDate] ASC
)
INCLUDE([CustId],[CurrencyId],[SiteId],[Amount]) ON [ReportData]
GO

CREATE TABLE [dbo].[SystemSettingsTest](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SName] [varchar](50) NOT NULL,
	[SValue] [varchar](200) NULL,
 CONSTRAINT [PK_SystemSettingsTest] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
) ON [SettingData]
) ON [SettingData]
GO

INSERT INTO dbo.SystemSettingsTest([SName], [SValue])
VALUES ('BatchSize', '5')



