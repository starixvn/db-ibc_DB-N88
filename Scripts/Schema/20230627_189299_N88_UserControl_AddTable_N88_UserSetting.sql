/*<info serverAlias="DBN88POL-N88_UserControl" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230620@Sally
	DB: DBN88POL-N88_UserControl
	Task: 189299 - MPA - Report on top/bottom X player
	Step 1:
		Design Schema & Table for new permissive function:
		
*/  
USE N88_UserControl
GO

IF OBJECT_ID (N'N88_UserSetting', N'U') IS NULL 
BEGIN
	CREATE TABLE [dbo].[N88_UserSetting](
		[UserId] [int] NOT NULL,
		[SettingKey] [nvarchar](50) NOT NULL,
		[SettingValue] [nvarchar](255) NOT NULL,
		[CreatedBy] [int] NULL,
		[CreatedDate] [datetime] NOT NULL,
		[ModifiedBy] [int] NULL,
		[ModifiedDate] [datetime] NOT NULL,
	 CONSTRAINT [PK_N88_UserSetting] PRIMARY KEY CLUSTERED 
	(
		[UserId] ASC,
		[SettingKey] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [NAP_UserControl_table]
	) ON [NAP_UserControl_table]

END
GO
