
--[dbo].[VNS_JOURNAL_VOUCHER] 9, 1
ALTER PROCEDURE [dbo].[VNS_JOURNAL_VOUCHER]
(
	@BatchNum int,
	@TransId int
)
AS
  declare @CompnyName nvarchar(254),
  @CompnyAddr nvarchar(254),
  @TaxIdNum nvarchar(40)
  
-- get company info
	select @CompnyName = PrintHeadr,
    @CompnyAddr = Manager,
    @TaxIdNum = TaxIdNum
	from OADM

	--Report 
	select distinct N'Ngày ' + ltrim(day(T1.RefDate)) + N' tháng ' + ltrim(month(T1.RefDate)) + N' năm ' + ltrim(year(t1.RefDate)) as RefDateInWord,
			@CompnyName as CompnyName, @CompnyAddr as CompnyAddr, @TaxIdNum as TaxIdNum, 
		case when T1.Transtype = 24 then N'PHIẾU THU' 
			when T1.Transtype = 46 then N'PHIẾU CHI'
			ELSE N'PHIẾU KẾ TOÁN' End VoucherName,
		case when T1.Transtype = 24 then N'RECEIPT VOUCHER' 
			when T1.Transtype = 46 then N'PAYMENT VOUCHER'
			ELSE N'JOURNAL VOUCHER' End VoucherNameEN	
			,T2.LineMemo DescriptionVN, 
		case when T1.Transtype = 24	then N'Mẫu số: 01-TT' 
			when  T1.Transtype = 46 then N'Mẫu số: 02-TT' 
			else ' ' end Mauso
		,Case when T1.Transtype  in (24,46) then N'(Ban hành theo QĐ số 15/2006/QĐ-BTC ngày 20/03/2006 của Bộ Trưởng BTC)' 
			else ' ' end Type1
		,case when 	T1.Transtype = 24 then N'Họ và tên người nộp tiền'
			when T1.Transtype = 46 then N'Họ và tên người nhận tiền'
			else ' ' end Hoten
		,	case when T1.TransType in (24,46) then T1.BaseRef else '' end as VoucherNo,
			Case 
				when T1.TransType = 24 and T5.DocType not in ('A') then T5.CardName 
				when T1.TransType = 46 and T6.DocType not in ( 'A') then T6.CardName 
				else T1.U_Company end Company,
			case when T1.TransType = 24  and T5.DocType not in ('A') then T5.address 
				when T1.TransType = 46 and T6.DocType not in ('A') then T6.Address else T1.U_Address end Address,
		T2.Account , T1.RefDate, T1.Memo as DescriptionEN
		,  isnull(sum(T2.Debit),0 ) as Debit, isnull(Sum(T2.Credit),0) as Credit, 
		isnull(sum(T2.FCDebit),0) FCDebit, isnull(sum(T2.FCCredit),0) FCCredit
		, T1.TransID, t1.BatchNum, T3.FrgnName, T3.AcctName
		, T2.LineMemo Remarks
		, T4.AmtWord,T4.Amount, T2.Ref1+'-'+T2.Ref2 as Document,
		T1.TransCurr, T1.FCTotal
		, case when isnull(T4.AmountFC,0)=0 then 0 else T4.Amount/T4.AmountFC end TransRate,
		t2.Line_ID
	into #Temp	
	from BTF1 as T2
	Join OBTF as T1 on T1.BatchNum = T2.BatchNum and T1.TransId=T2.TransId 
	Inner Join OACT as T3 on T2.Account = T3.AcctCode
	left join ORCT T5 on T5.DocEntry = T1.BaseRef and T1.TransType = 24
	Left  join OVPM T6 on T6.DocEntry = T1.BaseRef and T1.TransType = 46
	left join
		(select
			case when T2.Transtype not in  (46)  then dbo.fsothanhchu(isnull(sum(isnull(T0.Debit,0)),0))
				else dbo.fsothanhchu(sum(isnull(T0.Credit,0))) end AmtWord
			, case when T2.Transtype not in (46) then sum(isnull(T0.Debit,0)) 
				else sum(isnull(T0.Credit,0)) end Amount 
			, case when T2.Transtype not in (46) then sum(isnull(T0.FCDebit,0)) 
				else sum(isnull(T0.FCCredit,0)) end AmountFC 	
			from BTF1 T0
			Join OBTF T2 on T0.BatchNum = T2.BatchNum and T0.TransId=T2.TransId 
			join OACT T1 on T0.Account = T1.AcctCode
			where (T0.Account like case when T2.TransType In (24,46) then '11%' else T0.Account end)
				and T0.BatchNum=@BatchNum
				and T0.TransID = @TransID
			
			Group by T2.TransType
			) T4 on 1=1
	where T1.BatchNum=@BatchNum and  T1.TransId = @TransId
	group by T2.TransId, t2.Line_ID, T2.Account , T1.RefDate, T1.Memo, T1.TransID, t1.BatchNum, T2.Ref1, T2.Ref2, T1.TransType, T1.BaseRef, T5.DocType,T6.DocType ,
			 T3.AcctName ,T3.FrgnName , T2.LineMemo, T4.AmtWord,T4.Amount, T5.CardName, T6.CardName, T1.U_Company, T1.U_Address,
			 T5.Address, T6.Address, T1.TransCurr, T1.FcTotal
			 ,T2.LineMemo
			 ,T4.AmountFC	
	order by t1.TransId, t2.Line_ID
			 
	update #Temp set Company = t2.U_Company 
		from #Temp t1 inner join OBTF t2 on t1.TransId = t2.TransId and t1.BatchNum = t2.BatchNum
		where t1.Company is null or t1.Company = ''
	select * from #Temp	
	
  

 
  

