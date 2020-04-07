/*<info serverAlias="DBN88LOG-bodb_N88Log" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_LogExecSp_GetById]
	@LogId BIGINT
AS

/*
	Created: 20200314@Kos
	Task: Get exec SP log by ID
	DB: DBN88LOG.bodb_N88Log

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT ld.ID,
		ld.ActionID,
		ld.Data,
		ld.OldData,
		la.Items,
		la.SubItems
	FROM dbo.N88LOG_RUNSP_Detail AS ld WITH (NOLOCK)
		INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON ld.ActionId = la.ActionId
	WHERE ld.ID = @LogId
END
GO
