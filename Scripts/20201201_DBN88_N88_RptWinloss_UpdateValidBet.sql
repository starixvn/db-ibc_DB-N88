/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20201201@Percy
	DB: DBN88-bodb_N88
	Task: Manually update ValidBet amount on N88_RptWinloss
*/
use bodb_N88
go

-- Total row: 152,332
declare @batch int = 10000
while 1 = 1
begin
	update top (@batch) dbo.N88_RptWinloss with (rowlock)
	set ValidBet = TurnOver
	where WinlostDate between '2020-01-22' and '2020-07-31'
		and ValidBet is null

	if @@rowcount < @batch
		break
	else
		waitfor delay '00:00:00.280'
end