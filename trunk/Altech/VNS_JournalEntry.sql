


--[dbo].[VNS_JOURNAL_ENTRY] 3
ALTER PROCEDURE [dbo].[VNS_JOURNAL_ENTRY]
@TransId int
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
	select distinct @CompnyName as CompnyName, @CompnyAddr as CompnyAddr, @TaxIdNum as TaxIdNum, 
		case when T1.Transtype = 24 then N'PHIẾU THU (RECEIPT VOUCHER)' when T1.Transtype = 46 then N'PHIẾU CHI (PAYMENT VOUCHER)'
			ELSE N'PHIẾU KẾ TOÁN (JOURNAL VOUCHER)' End VoucherName, T1.U_MemoVN, 
			case when T1.TransType in (24,46) then T1.BaseRef else '' end as VoucherNo,
			Case when T1.TransType = 24  and T5.DocType not in ('A') then T5.CardName 
				when T1.TransType = 46 and T6.DocType not in ( 'A') then T6.CardName else T1.U_Company end Company,
			case when T1.TransType = 24  and T5.DocType not in ('A') then T5.address 
				when T1.TransType = 46 and T6.DocType not in ('A') then T6.Address else T1.U_Address end Address,
		T2.Account , T1.RefDate, T1.Memo as DescriptionEN,  isnull(sum(T2.Debit),0 ) as Debit, isnull(Sum(T2.Credit),0) as Credit, 
		isnull(sum(T2.FCDebit),0) FCDebit, isnull(sum(T2.FCCredit),0) FCCredit, T1.TransID, 
		T3.FrgnName, T3.AcctName, T2.LineMemo Remarks, T4.AmtWord,T4.Amount, T2.Ref1+'-'+T2.Ref2 as Document,
		T1.TransCurr, T1.FCTotal
	from JDT1 as T2
	Join OJDT as T1 on T1.TransID = T2.TransID 
	Inner Join OACT as T3 on T2.Account = T3.AcctCode
	left join ORCT T5 on T5.DocEntry = T1.BaseRef and T1.TransType = 24
	Left  join OVPM T6 on T6.DocEntry = T1.BaseRef and T1.TransType = 46
	left join
		(select
			case when T2.Transtype not in  (46)  then dbo.fsothanhchu(isnull(sum(isnull(T0.Debit,0)),0))
				else dbo.fsothanhchu(sum(isnull(T0.Credit,0))) end AmtWord
			, case when T2.Transtype not in (46) then sum(isnull(T0.Debit,0)) 
				else sum(isnull(T0.Credit,0)) end Amount 
			from JDT1 T0
			Join OJDT T2 on T2.TransID = T0.TransId 
			join OACT T1 on T0.Account = T1.AcctCode
			where (T0.Account like case when T2.TransType In (24,46) then '11%' else T0.Account end)
				and T0.TransID = @TransID
			Group by T2.TransType
			) T4 on 1=1
	where T1.TransId = @TransId
	group by T2.Account , T1.RefDate, T1.Memo, T1.TransID, T1.U_MemoVN, T2.Ref1, T2.Ref2, T1.TransType, T1.BaseRef, T5.DocType,T6.DocType ,
			 T3.AcctName ,T3.FrgnName , T2.LineMemo, T4.AmtWord,T4.Amount, T5.CardName, T6.CardName, T1.U_Company, T1.U_Address,
			 T5.Address, T6.Address, T1.TransCurr, T1.FcTotal
  
  

 
  

