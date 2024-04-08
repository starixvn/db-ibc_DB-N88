/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20240403@Sally
	DB: DBN88-bodb_N88
	Task: MPA - Repull data of V8 on Jul - [Redmine: #192617]
		- Step 2 : Re-sum N88_SumWinloss data from Mar 2024
*/
USE bodb_N88
GO

---Regen Task_N88_SumWinloss Mar 2024
	DECLARE	@FromDate   SMALLDATETIME = '2024-03-01'
		,@ToDate		SMALLDATETIME = '2024-04-03'
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
