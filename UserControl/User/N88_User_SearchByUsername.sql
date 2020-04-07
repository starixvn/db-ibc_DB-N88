/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_SearchByUsername]
	@Username		NVARCHAR(50)
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT = 0 OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Search user by username
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec INT
		,@LastRec INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	-- Gets total rows
	SET @TotalRows = (
			SELECT COUNT(1)
			FROM dbo.N88_Users AS c WITH (NOLOCK)
			WHERE c.username LIKE '%' + @Username + '%'
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.N88_Users WITH (NOLOCK)
					WHERE UserId = c.UserId
					)
			)

	-- Gets data
	SELECT TOP (@PageSize) *
	FROM (
		SELECT c.UserId
			,c.firstname
			,c.lastname
			,c.username
			,ROW_NUMBER() OVER (ORDER BY c.username) AS num
		FROM dbo.N88_Users AS c WITH (NOLOCK)
		WHERE c.username LIKE '%' + @Username + '%'
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.N88_Users WITH (NOLOCK)
				WHERE UserId = c.UserId
				)
		) AS TEMP
	WHERE TEMP.num BETWEEN @FirstRec AND @LastRec
	ORDER BY TEMP.num
END

GO
