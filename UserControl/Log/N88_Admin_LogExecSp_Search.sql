/*<info serverAlias="DBN88LOG-bodb_N88Log" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[N88_Admin_LogExecSp_Search]
	@Username		NVARCHAR(50)	= ''
	,@Name			NVARCHAR(50)	= ''
	,@FilterType	INT
	,@SiteId	TINYINT				= NULL
	,@From			DATETIME
	,@To			DATETIME
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT				= 0	OUTPUT	
AS

/*
	Created: 20200326@Scofield
	Task: Search exec SP log for N88 Admin
	DB: DBN88LOG.bodb_N88Log

	Revisions:
		- 20200326@Scofield: Created [RedmineID: #130374]
		- 20230615@Hogan: get user setting action [RedmineID: #189299]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec	INT,
		@LastRec		INT,
		@N88_User_Insert INT = 100,
		@N88_User_Update INT = 200,
		@N88_User_UpdatePassword INT = 3,
		@N88_User_UpdateSite INT = 404,
		@N88_User_AssignFunction INT = 304,		
		@N88_Group_Insert INT = 102,
		@N88_Group_UpdateStatus INT = 204,
		@N88_Group_Update INT = 203,
		@N88_Group_AssignFunction INT = 302,
		@N88_Setting_UpdateByUser INT = 500

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	IF @FilterType = 1	-- User
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM
				dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 1 -- Object type : User
				AND u.username LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND u.IsLicenseeUser = 1 AND u.SourceSiteId = @SiteId
				AND lg.ActionId IN (@N88_User_Insert, @N88_User_Update, @N88_User_UpdatePassword, @N88_User_UpdateSite, @N88_User_AssignFunction, @N88_Setting_UpdateByUser)
		)		

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
			 SELECT 
				    lg.Id,
				    lg.LogDate,
				    u.username AS Name,
				    cu1.username AS Modifier,
				    la.ActionId,
				    la.ActionName,
				    ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
				    dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				    INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
				    INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
				    INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
				    lg.ObjectTypeId = 1
				    AND u.username LIKE '%' + @Name + '%'
				    AND lg.LogDate BETWEEN @From AND @To
				    AND cu1.username LIKE '%' + @Username + '%'
				    AND u.IsLicenseeUser = 1 AND u.SourceSiteId = @SiteId
				    AND lg.ActionId IN (@N88_User_Insert, @N88_User_Update, @N88_User_UpdatePassword, @N88_User_UpdateSite, @N88_User_AssignFunction, @N88_Setting_UpdateByUser)
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END

	IF @FilterType = 2 -- Group
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				dbo.N88Log_RUNSP AS lg WITH(NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Groups AS g WITH(NOLOCK) ON lg.ObjectId = g.GroupId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH(NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH(NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 2
				AND g.GroupName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND g.IsLicenseeGroup = 1 AND g.SourceSiteId = @SiteId
				AND lg.ActionId IN (@N88_Group_Insert, @N88_Group_UpdateStatus, @N88_Group_Update, @N88_Group_AssignFunction)
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					g.GroupName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					dbo.N88Log_RUNSP AS lg WITH(NOLOCK)
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Groups AS g WITH(NOLOCK) ON lg.ObjectId = g.GroupId
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH(NOLOCK) ON lg.UserId = cu1.UserId
					INNER JOIN dbo.N88Log_Action AS la WITH(NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 2
					AND g.GroupName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
					AND g.IsLicenseeGroup = 1 AND g.SourceSiteId = @SiteId
					AND lg.ActionId IN (@N88_Group_Insert, @N88_Group_UpdateStatus, @N88_Group_Update, @N88_Group_AssignFunction)
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END	
END
GO