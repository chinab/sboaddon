

--[VNS_RPT_INPUTVAT] 2010,4
ALTER proc [dbo].[VNS_RPT_INPUTVAT] 
		@Year smallint, 
		@Month smallint
as
	select isnull(a.TypeName,'')TypeName , a.TaxType1, a.Period, isnull(b.U_REMARKS,'') U_REMARKS, isnull(b.U_SERIALNO,'')U_SERIALNO, isnull(b.U_INVOICENO,'')U_INVOICENO, isnull(b.U_INVDATE,'')U_INVDATE
		--,b.U_Invoiceno SHD 
		,CONVERT(numeric(18,0), case when isnumeric(b.U_INVOICENO)= 0 OR charindex(',',b.U_INVOICENO)<>0 then 0 else b.U_INVOICENO end) SHD
		,isnull(b.U_BPNAME,'')U_BPNAME, isnull(b.U_TAXCODE,'') U_TAXCODE, isnull(b.VatAmount,0) VatAmount, isnull(b.BaseSum,0) BaseSum, b.VatRate, b.TransID
	from
	(	select N'1. Hàng hóa, dịch vụ dùng riêng cho SXKD chịu thuế GTGT' TypeName, 
			'1001' TaxType1, Convert(nvarchar(20),@Month)+'/'+Convert(nvarchar(20),@Year) Period
		union all
		select N'2. Hàng hóa, dịch vụ dùng riêng cho SXKD không chịu thuế GTGT' TypeName,
			 '1002' TaxType1, Convert(nvarchar(20),@Month)+'/'+Convert(nvarchar(20),@Year) Period
		union all
		select N'3. Hàng hóa, dịch vụ dùng chung cho SXKD chịu thuế và không chịu thuế GTGT' TypeName, 
			'1003' TaxType1, Convert(nvarchar(20),@Month)+'/'+Convert(nvarchar(20),@Year) Period
		) a 
	left join 
		( select a.LineMemo as U_REMARKS, a.Ref1 as U_SERIALNO, a.REf2 as U_INVOICENO, a.TaxDate as U_INVDATE,
				 a.U_BPNAME, a.U_TAXCODE, '1001' as U_TaxType, isnull(Debit,0)-isnull(Credit,0) VatAmount, BaseSum, a.VatRate, a.TransID
			from JDT1 a WITH(NOLOCK) 
			left join  --chi lay nhung trans khong BI CANCEL
				(select transtype, transid , Memo as U_Remarks
					 from OJDT a with(nolock) 
					 where month(a.refDate)=@Month and Year(a.refDate)=@Year 
						and (a.TransType=30 or a.TransType = 69 or a.TransType =46) 
						and StornoToTr is not null 
					 union all
					 select transtype, StornoToTr ,Memo as U_Remarks
					 from OJDT a with(nolock) 
					 where month(a.refDate)=@Month and Year(a.refDate)=@Year 
						and (a.TransType=30 or a.TransType = 69 or a.TransType =46 )
						and StornoToTr is not null
						
				 ) b on A.TRANSTYPE = B.TRANSTYPE AND a.transid = b.transid
					where month(a.refDate)=@Month and Year(a.refDate)=@Year 
					and (a.TransType=30 or a.TransType = 69 or a.TransType =46 ) 
					and a.Account like '133%' and (a.ContraAct not like '333%') 
					AND B.TRANSID IS NULL
			) b on a.TaxType1= isnull(b.U_TaxType,'1001')
		order by a.TaxType1, U_INVDATE,SHD, VatRate













