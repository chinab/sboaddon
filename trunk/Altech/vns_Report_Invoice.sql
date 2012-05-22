
GO
/****** Object:  StoredProcedure [dbo].[vns_Report_Invoice]    Script Date: 05/21/2012 08:59:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--select * from VNS_INVOICE_DETAIL where invID=1376
--select * from VNS_INVOICE where InvID=1376
 --where InvID=524
--select U_UBangke,* from OINV where U_UBangke<>'0'
--select * from INV1 where DocEntry=524
--select DocTotal,DiscSum,* from OINV where DocEntry=524


--[dbo].[vns_Report_Invoice] 1376
alter Procedure [dbo].[vns_Report_Invoice]
	@InvID int
As

declare	@TaxMethod int, -- My Tax Code will be get from: 1 = Company Detail, 2 = Warehouse
		@MyTaxCode nvarchar(32),
		-- base on TaxCode (Warehouse or Company) then MyAddress will be goten with corresponding
		@MyAddress nvarchar(254),  
		@MyCompanyName nvarchar(100),
		@MyAccountNo nvarchar(200),
		@MyPhoneNo nvarchar(20),
		@MyFaxNo   nvarchar(20),
		@NoOfSerial int, -- Number of page
		@LogoPath nvarchar(400)

select	@TaxMethod = TaxMethod,
		@MyTaxCode = TaxCode, -- Tax code of company detail
		@LogoPath = LogoPath
  from	VNS_OPTIONS

-- Get number of pages
select	@NoOfSerial = count(1)
  from	VNS_INVOICE a inner join VNS_INVOICE_SETUP b on a.InvName = b.InvName
inner join VNS_SERIAL c on b.ID = c.IDSetup 
 where a.InvID= @InvID

-- get company information
select 	@MyCompanyName = a.CompnyName,
	   	@MyAddress = a.CompnyAddr,
	   	@MyAccountNo = a.DflBnkAcct + ' ' + b.BankName + ', ' + a.DflBranch,
	   	@MyPhoneNo = Phone1,
		@MyFaxNo = Fax
  from  OADM a
inner join ODSC b on a.DflBnkCode = b.BankCode

-- if TaxCode get from Warehouse
if @TaxMethod = 2 
begin
	declare @WhsCode nvarchar(8)
	declare @ItemType int -- SAP Invoice Type is Item (Value = 0) or Service (1)

	set @WhsCode = ''
	set @MyAddress = ''
	set @MyTaxCode = ''

	declare @DocType int
	select	@DocType = DocType,
			@MyTaxCode = IsNull(MyTaxCode, ''),
			@WhsCode = IsNull(WhsCode, ''),
			@ItemType = IsNull(ItemType, 0)
	  from VNS_INVOICE where InvID = @InvID

	-- if Document is JE or not JE and Item Type is SERVICE
	-- then TaxCode will be get from VnsInvoice directly
	if @DocType = 30
	begin
		-- get address from TaxCode of Warehouse
		select	@MyAddress = IsNull(Street, '') + ', ' + IsNull(City, '')
		  from	OWHS 
		 where	IsNull(FedTaxID, '') = @MyTaxCode
	end
	else if @ItemType = 1 -- Service
	begin
		-- get address from TaxCode of Warehouse
		select	@MyAddress = IsNull(Street, '') + ', ' + IsNull(City, '')
		  from	OWHS 
		 where	IsNull(FedTaxID, '') = @MyTaxCode
	end
	-- Other Documents then TaxCode, Address will be got from WhsCode VnsInvoice
	else
	begin
		select	@MyTaxCode = FedTaxID,
				@MyAddress = IsNull(Street, '') + ', ' + IsNull(City, '')
		  from	OWHS
		 where	WhsCode = @WhsCode
	end
end

--Get Total
DECLARE @Total9 DECIMAL(19,0) --SUM(AmountDetail2
DECLARE @Total10 DECIMAL(19,0)--Freight
DECLARE @Total11 DECIMAL(19,0)--Freight*(1+(TaxPercent/100))
DECLARE @Total12 DECIMAL(19,0)--(({UnitPrice}+{@Total10})*{TaxPercent})/100
DECLARE @Total13 DECIMAL(19,0)--@Total9+@Total11
DECLARE @Total14 DECIMAL(19,0)--@Total9+@Total11
DECLARE @Total15 DECIMAL(19,0)--@Total9+@Total11

SELECT 
@Total10=ISNULL(f.U_UFreight,0),
@Total11=ISNULL(f.U_UFreight,0) + (ISNULL(f.U_UFreight,0)*ISNULL(a.TaxPercent,0))/100,--ISNULL(f.U_UFreight,0)*(1+(a.TaxPercent/100)),
@Total12=a.TaxAmount,--(SUM((ISNULL(b.UnitPrice,0)*(1+ISNULL(a.TaxPercent,0)/100))*ISNULL(b.Quantity,0)))/(1+ISNULL(a.TaxPercent,0)),--((SUM((ISNULL(b.UnitPrice,0)/(1+ISNULL(a.TaxPercent,0)))*ISNULL(b.Quantity,0))*a.TaxPercent)/100)+ ISNULL(f.U_UFreight,0),
@Total14=ISNULL(f.U_UAdvance,0)
FROM VNS_INVOICE a inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
where a.InvID = @InvID
group by b.UnitPrice,a.TaxPercent,b.Quantity,a.TaxPercent,f.U_UFreight,f.U_UAdvance,a.TaxAmount

SELECT 
@Total9= a.PaymentAmount,
@Total13=a.PaymentAmount+ISNULL(@Total11,0)
FROM VNS_INVOICE a inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
where a.InvID = @InvID
group by b.UnitPrice,a.TaxPercent,b.Quantity,a.TaxPercent,f.U_UFreight,f.U_UAdvance,a.TaxAmount, a.PaymentAmount



SET @Total15=ISNULL(@Total13,0)-ISNULL(@Total14,0)

declare @bangke nvarchar(15)
set @bangke = ''

select @bangke = isnull(T1.U_UBangKe,'0') from VNS_INVOICE T0
left join OINV T1 on T1.DocEntry = T0.DocEntry
where T0.InvID = @InvID
-- out report
--neu hoa don co bang ke
if @bangke <> '0'
	begin
	print 'No'
		select row_number() over (partition by d.SerialName order by (select 1)) as Stt, d.SerialName, d.SerialDescription, @MyCompanyName as MyCompanyName, @MyAddress as MyCompanyAddress,
			@MyTaxCode as MyTaxCode, @MyAccountNo as MyAccountNo, @MyPhoneNo MyPhoneNo, @MyFaxNo MyFaxNo, cast(@NoOfSerial as varchar(2)) as NoOfSerial,
			a.InvName, a.InvNo, a.InvDate, a.FullName, a.CompanyName, a.Address, a.TaxCode, c.InvType, @LogoPath as LogoPath,
			a.ContractNo, a.ContractDate, a.PlaceOfDelivery, a.PlaceOfReceipt, a.BillOfLading, a.ContainerNo, a.TransportCompanyName,
			a.AccountNo, e.Name as PaymentMeans, a.TaxPercent, (f.DocTotal - f.VatSum + f.DiscSum) as Amount, a.TaxAmount, a.PaymentAmount, a.IsCopy, 
			isnull(f.u_ucomment, N'Kèm theo Bảng kê chi tiết số'+ ' ' + @bangke)ItemName, cast('' as nvarchar(20)) as UOM, 1 Quantity
			, (f.DocTotal - f.VatSum + f.DiscSum) UnitPrice
			, a.PaymentAmount AmountDetail,
			G.Phone1 Phone, G.Fax Fax, f.Address2 ShipToAddress, 
			(select isnull(SUM(Quantity), 0) from VNS_INVOICE_DETAIL where InvID = @InvID) AS MasterQty,
			os.SlpName AS SalesPerson,
			f.NumAtCard AS CustomerPO,
			f.U_UPickSlip AS PickingSlip,
			ISNULL(f.U_UFreight,0) AS Freight,
			ISNULL(f.U_UAdvance,0) AS Advance,
			cast('' as nvarchar(30)) ItemCode, @bangke BangKe,
			TaxUPrice= a.Amount*(1+a.TaxPercent/100),
			AmountDetail2=(f.DocTotal - f.VatSum + f.DiscSum), -- a.Amount ,
			f.PeyMethod,
			@Total9 AS Total9,
			@Total10 AS Total10,
			@Total11 AS Total11,
			@Total12 AS Total12,
			@Total13 As Total13,
			@Total14 AS Total14,
			@Total15 AS Total15,
			AmountInWordsVN=dbo.fsothanhchu(@Total13),
			AmountInWordsEN=dbo.uf_Num_ToEnglishWords(@Total13), --+ ' VietNam Dong'
			
			f.DiscSum as DiscountNoVAT,
			(ISNULL((f.DocTotal - f.VatSum + f.DiscSum),0)-ISNULL(f.DiscSum,0)) as TotalNoVAT, -- tong gia tri hoa don chua VAT
			(@Total12+(ISNULL((f.DocTotal - f.VatSum + f.DiscSum),0)-ISNULL(f.DiscSum,0))) as TotalVAT
			
		--	h.VatPrcnt TaxPercentDetail, h.VatSum TaxDetail
			
		 from VNS_INVOICE a
		inner join  VNS_INVOICE_SETUP c on a.InvName = c.InvName
		inner join VNS_SERIAL d on c.ID = d.IDSetup
		left join [@VNS_PAYMENT_MEANS] e on a.PaymentMeans = e.Code
		LEFT JOIN OINV f ON f.DocEntry = a.DocEntry		
		LEFT JOIN OCRD G ON G.CardCode = f.CardCode
		LEFT JOIN OSLP os ON os.EmpID=f.SlpCode

		where a.InvID = @InvID
	end

else
	--declare @UOM as nvarchar(100)
	--select @UOM = T3.unitMsr
	--from VNS_INVOICE T1 inner join VNS_INVOICE_DETAIL T2 on T1.InvID = T2.InvID
	--left join INV1 T3 on T3.DocEntry = T1.DocEntry
	
	--where T1.InvID = @InvID
	
	--if ISNULL(@UOM,'') = ''
	--	begin 
	--		select @UOM = T3.SalUnitMsr
	--		from VNS_INVOICE T1 inner join VNS_INVOICE_DETAIL T2 on T1.InvID = T2.InvID
	--		left join OITM T3 on T3.ItemName = T2.ItemName
	--		where T1.InvID = @InvID
	--	end
		
	select row_number() over (partition by d.SerialName order by (select 1)) as Stt, d.SerialName, d.SerialDescription, @MyCompanyName as MyCompanyName, @MyAddress as MyCompanyAddress,
		@MyTaxCode as MyTaxCode, @MyAccountNo as MyAccountNo, @MyPhoneNo MyPhoneNo, @MyFaxNo MyFaxNo, cast(@NoOfSerial as varchar(2)) as NoOfSerial,
		a.InvName, a.InvNo, a.InvDate, a.FullName, a.CompanyName, a.Address, a.TaxCode, c.InvType, @LogoPath as LogoPath,
		a.ContractNo, a.ContractDate, a.PlaceOfDelivery, a.PlaceOfReceipt, a.BillOfLading, a.ContainerNo, a.TransportCompanyName,
		a.AccountNo, e.Name as PaymentMeans, a.TaxPercent, (f.DocTotal - f.VatSum + f.DiscSum) as Amount, a.TaxAmount, a.PaymentAmount, a.IsCopy, 
		f1.Dscription as ItemName,
		case when isnull(f1.unitMsr,'') <> '' then f1.unitMsr
		
			ELSE (select top 1 T3.SalUnitMsr
					from VNS_INVOICE T1
					inner join VNS_INVOICE_DETAIL T2 on T1.InvID = T2.InvID
					left join INV1 t4 ON t4.DocEntry = T1.DocEntry AND T4.Dscription = T2.ItemName
					left join OITM T3 on T4.ItemCode = T3.ItemCode
					where T1.InvID = @InvID )
				
		end as UOM,
		
		ISNULL(f1.Quantity,0) AS Quantity, f1.Price UnitPrice, --ISNULL(f1.Price,0) AS UnitPrice, 
		ISNULL(f1.LineTotal,0) as AmountDetail,
		G.Phone1 Phone, G.Fax Fax, f.Address2 ShipToAddress, 
		(select isnull(SUM(Quantity), 0) from VNS_INVOICE_DETAIL where InvID = @InvID) AS MasterQty,
		os.SlpName AS SalesPerson,
		f.NumAtCard AS CustomerPO,
		f.U_UPickSlip AS PickingSlip,
		ISNULL(f.U_UFreight,0) AS Freight,
		ISNULL(f.U_UAdvance,0) AS Advance,
		--(SELECT top 1 ItemCode FROM INV1 WHERE INV1.DocEntry = f.DocEntry AND INV1.Dscription = b.ItemName) ItemCode
		f1.ItemCode
		,@bangke BangKe,
		TaxUPrice=ISNULL(f1.Price,0) + (ISNULL(f1.Price,0)*ISNULL(a.TaxPercent,0))/100,
		AmountDetail2= f1.LineTotal, 
		f.PeyMethod,
		@Total9 AS Total9,
		@Total10 AS Total10,
		@Total11 AS Total11,
		@Total12 AS Total12,
		@Total13 As Total13,
		@Total14 AS Total14,
		@Total15 AS Total15,
		AmountInWordsVN=dbo.fsothanhchu(@Total13),
		AmountInWordsEN=dbo.uf_Num_ToEnglishWords(@Total13),  --+ ' VietNam Dong'
		
		f.DiscSum as DiscountNoVAT,
		(ISNULL((f.DocTotal - f.VatSum + f.DiscSum),0)-ISNULL(f.DiscSum,0)) as TotalNoVAT, -- tong gia tri hoa don chua VAT
		(@Total12+(ISNULL((f.DocTotal - f.VatSum + f.DiscSum),0)-ISNULL(f.DiscSum,0))) as TotalVAT,
		f.DocEntry
	--	h.VatPrcnt TaxPercentDetail, h.VatSum TaxDetail
	
	from VNS_INVOICE a --inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
	inner join  VNS_INVOICE_SETUP c on a.InvName = c.InvName
	inner join VNS_SERIAL d on c.ID = d.IDSetup
	left join [@VNS_PAYMENT_MEANS] e on a.PaymentMeans = e.Code
	LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
	left join INV1 f1 on f1.DocEntry = a.DocEntry
	LEFT JOIN OCRD G ON G.CardCode = f.CardCode
	LEFT JOIN OSLP os ON os.EmpID=f.SlpCode
	where a.InvID = @InvID
	
	--update #Temp set UnitPrice = t2.Price, AmountDetail2 = t2.LineTotal
	--	from #Temp t1 inner join INV1 t2 on t1.DocEntry = t2.DocEntry
	--select * from #Temp	
--select * from VNS_INVOICE
--select * from VNS_INVOICE_DETAIL

return (0)

--sp_help vns_invoice