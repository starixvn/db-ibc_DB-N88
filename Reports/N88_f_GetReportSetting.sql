/*<info serverAlias="DBN88-bodb_N88" executers="wsv_lap" isFunction="1" isNested="1"></info>*/
USE bodb_N88
GO

CREATE FUNCTION [dbo].[N88_f_GetReportSetting]
(
	@ReportSettingTypeId BIGINT,
	@SiteIds VARCHAR(MAX)
)
RETURNS TABLE
AS
/*
	Created: 20240401@Sally
	DB: DBN88-bodb_N88
	Task: Support House Win Loss [RedmineID: #201107]
	
	Revisions:
		- 20240401@Sally: Initialize SP [Redmine: #201107]

	Param's Explanation:
		 - @ReportSettingTypeId 
			. 1: DataView Full
			. 2: DataView House
			. 3: Dataview ShareHolder
		- @SiteIds
			. 1: N88
			. 2: N8G
			. 3: N8B

*/
RETURN
	SELECT ReportSettingTypeId, SiteId, CurrencyType, CurrencyId, PercentageValue, FromDate, ToDate
	FROM dbo.ReportSetting rs WITH(NOLOCK)
	WHERE rs.ReportSettingTypeId = @ReportSettingTypeId
		AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), rs.SiteId) + ',%'

GO
