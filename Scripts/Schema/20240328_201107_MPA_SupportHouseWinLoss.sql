/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240328@Sally
	Task: Support House Win Loss [RedmineID: #201107]
	DB: DBN88/bodb_N88
	- Create table Report Setting
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO
CREATE TABLE [dbo].[ReportSettingType](
	[ReportSettingTypeId] [INT] IDENTITY(1,1) NOT NULL,
	[Type] VARCHAR(50) NOT NULL,
	[SettingValue] VARCHAR(50) NOT NULL,
	[Description] VARCHAR(255) NULL,
	[DisplayOrder] SMALLINT NOT NULL
 CONSTRAINT [PK_ReportSettingType] PRIMARY KEY CLUSTERED 
(
	[ReportSettingTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)  ON [SettingData]
) ON [SettingData]
GO



CREATE TABLE [dbo].[ReportSetting](
	[ReportSettingId] [INT] IDENTITY(1,1) NOT NULL,
	[ReportSettingTypeId] [INT]  NOT NULL,
	[SiteId] INT NOT NULL,
	[CurrencyType] VARCHAR(30) NOT NULL,
	[CurrencyId] INT NULL,
	[PercentageValue] DECIMAL(9,8) NOT NULL,
	[FromDate] DATETIME NOT NULL,
	[ToDate] DATETIME NOT NULL
 CONSTRAINT [PK_ReportSetting] PRIMARY KEY NONCLUSTERED 
(
	[ReportSettingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)  ON [SettingData]
) ON [SettingData]
GO

/****** Object:  Index [CIX_ReportSetting_ReportSettingType]    Script Date: 3/29/2024 3:57:11 PM ******/
CREATE CLUSTERED INDEX [CIX_ReportSetting_ReportSettingType] ON [dbo].[ReportSetting]
(
	[ReportSettingTypeId] ASC,
	[SiteId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [SettingData]
