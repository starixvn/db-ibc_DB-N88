/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
CREATE PROCEDURE N88_GetListGameType
AS
/*
	Created: 20200511@Sol
	Task : N88 - Get list gametype
	DB: DBN88-bodb_N88
	
	Revisions:
		- 20200511@Sol: Get list gametype [Redmine:#133254]
		- 20210423@Sol: Order by type - [Redmine:#139333]
	
*/
BEGIN
	
	SET NOCOUNT ON;

	SELECT [Type], TypeName 
	FROM dbo.TpGameType t WITH(NOLOCK)
	ORDER BY t.[Type]

END

GO