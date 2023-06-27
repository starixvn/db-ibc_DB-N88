/*<info serverAlias="DBN88POL-N88_UserControl" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230620@Sally
	DB: DBN88-bodb_N88
	Task: 189299 - MPA - Report on top/bottom X player
	Step 3: 
		Migrate data DataRangeLimitation 
				
*/ 
USE N88_UserControl
GO
----Insert data DataRangeLimitation into new structure
INSERT INTO dbo.N88_UserSetting(
	UserId
	,SettingKey
	,SettingValue
	,CreatedDate
	,ModifiedDate
)
SELECT t.UserId
	,t.SettingKey
	,t.SettingValue
	,SYSDATETIME() AS CreatedDate
	,SYSDATETIME() AS CreatedDate
FROM (
	SELECT u.UserId
		,'LimitDays' AS SettingKey
		,DataRangeLimitation AS SettingValue
	FROM dbo.N88_Users u WITH (NOLOCK)
	WHERE u.DataRangeLimitation IS NOT NULL
)t
	LEFT JOIN dbo.N88_UserSetting us WITH (NOLOCK) ON us.UserId = t.UserId
													AND us.SettingKey = t.SettingKey
WHERE us.UserId IS NULL

GO
