/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20230814@Sally
	DB: DBN88-bodb_N88
	Task: MPA - Repull data of V8 on Jul - [Redmine: #192617]
		- Step 2 : Re-sum N88_SumWinloss data on Jul 19, 2023
*/
USE bodb_N88
GO
-- Drop old data Temp
DROP TABLE IF EXISTS dbo.N88_SumWinloss_Temp20230519
GO
-- 1. Backup data N88_SumWinloss 2023-07-19
	DECLARE @FromDate SMALLDATETIME = '2023-07-19'
			,@ToDate SMALLDATETIME  = '2023-07-20'

	--~43k rows
	SELECT *
	INTO N88_SumWinloss_Temp20230719
	FROM dbo.N88_SumWinloss R WITH (NOLOCK)
	WHERE R.SettledTime >= @FromDate
		AND R.SettledTime < @ToDate
	CREATE CLUSTERED INDEX IX_N88_SumWinloss_Temp20230519_SiteId_SettledTime_CustId ON N88_SumWinloss_Temp20230719 (SiteId,SettledTime,CustId)

GO
---2.Regen Task_N88_SumWinloss 2023-07-19

	DECLARE @WinlostDate SMALLDATETIME = '2023-07-19'
	EXEC dbo.Task_N88_SumWinloss @WinlostDate = @WinlostDate


GO