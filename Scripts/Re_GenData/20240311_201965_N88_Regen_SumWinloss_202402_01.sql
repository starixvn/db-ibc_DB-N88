/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20240311@Sally
	DB: DBN88-bodb_N88
	Task: MPA - Repull data of Fe - [Redmine: #201965]
		- Step 1 : Re-sum N88_SumWinloss data 2024-02
*/
USE bodb_N88
GO
-- Drop old data Temp
DROP TABLE IF EXISTS dbo.N88_SumWinloss_Temp20230719
GO

GO
---.Regen Task_N88_SumWinloss 2024-02

	DECLARE	@FromDate   SMALLDATETIME = '2024-02-01'
		,@ToDate		SMALLDATETIME = '2024-02-29'
		,@WinlostDate	SMALLDATETIME

	SELECT @WinlostDate = @FromDate
	WHILE  (@WinlostDate <= @ToDate)
	BEGIN
		BEGIN
			EXEC dbo.Task_N88_SumWinloss @WinlostDate = @WinlostDate
		END	
		PRINT @WinlostDate
		SELECT @WinlostDate = DATEADD(DAY, 1, @WinlostDate)
		WAITFOR DELAY '000:00:00.280'
	END



GO