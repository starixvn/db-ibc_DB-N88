/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20240716@Sally
	DB: DBN88-bodb_N88
	Task: 
		- Regen Task_N88_SumWinloss 2024-07-02
		
*/  
-- Regen Task_N88_SumWinloss 2024-07-02

	DECLARE	@FromDate   SMALLDATETIME = '2024-07-02'
		,@ToDate		SMALLDATETIME = '2024-07-15'
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
