/*<info serverAlias="DBN88-bodb_N88" executers="wsv_lap" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

CREATE PROCEDURE [dbo].[N88_ReportSettingType_Sel]	
	@ReportSettingType VARCHAR(50)
AS
/*
	Created: 20240401@Sally
	DB: DBN88-bodb_N88
	Task: Support House Win Loss [RedmineID: #201107]
	
	Revisions:
		- 20240401@Sally: Initialize SP [Redmine: #201107]

	Param's Explanation:
		- @ReportSettingType 
			. DATAVIEW 
	
*/
BEGIN
	SET NOCOUNT ON;

	SELECT rst.ReportSettingTypeId
		,rst.Type
		,rst.SettingValue
		,rst.Description
		,rst.DisplayOrder
	FROM dbo.ReportSettingType rst WITH(NOLOCK)
	WHERE rst.[Type] = @ReportSettingType
END
