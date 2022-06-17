/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
USE bodb_N88
GO

ALTER FUNCTION [dbo].[N88_f_GetSystemSettings]
(
	@SName VARCHAR(50)
)
RETURNS VARCHAR(200)
AS

/*
	Created: 20220222@Percy
	DB: DBN88-bodb_N88
	Task: Core function get data in SystemSettings

	Revisions:
		- 20220222@Percy: Initialize function [RedmineID: #167823]
*/

BEGIN
	DECLARE @SValue VARCHAR(200) = ''
	SELECT  @SValue = SValue FROM dbo.SystemSettings WITH (NOLOCK) WHERE SName = @SName
	
	RETURN @SValue
END
GO