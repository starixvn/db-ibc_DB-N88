/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested="1"></info>*/
/*
	Created: 20240611@Sally
	DB: DBN88-bodb_N88
	Task: 
		- Regen Task_N88_SumWinloss 2024-05-20
		
*/  
-- Regen Task_N88_SumWinloss 2024-05-20

	DECLARE	@FromDate   SMALLDATETIME = '2024-05-20'
		,@ToDate		SMALLDATETIME = '2024-05-31'
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
