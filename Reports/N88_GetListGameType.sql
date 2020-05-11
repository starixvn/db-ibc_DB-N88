/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE N88_GetListGameType
AS
/*
	Created: 20200511@Sol
	Task : N88 - Get list gametype
	DB: DBEXT-bodb02
	
	Revisions:
		- 20200511@Sol: Get list gametype [Redmine:#133254]
	
*/
BEGIN
	
	SET NOCOUNT ON;

	SELECT [Type], TypeName 
	FROM bodb_3rdProduct.dbo.TpGameType WITH(NOLOCK)

END

GO