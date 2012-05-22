
--[dbo].[vns_Report_Invoice] 20
ALTER Procedure [dbo].[vns_Report_Invoice]
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
@Total9=SUM(ISNULL(b.Quantity,0)*ISNULL(b.UnitPrice,0) + (ISNULL(b.Quantity,0)*ISNULL(round(b.UnitPrice,1),0)*ISNULL(a.TaxPercent,0))/100),--SUM((ISNULL(b.UnitPrice,0)*(1+ISNULL(a.TaxPercent,0))/100)*ISNULL(b.Quantity,0)),
@Total13=SUM(ISNULL(b.Quantity,0)*ISNULL(b.UnitPrice,0) + (ISNULL(b.Quantity,0)*ISNULL(round(b.UnitPrice,1),0)*ISNULL(a.TaxPercent,0))/100)+ISNULL(@Total11,0)
FROM VNS_INVOICE a inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
where a.InvID = @InvID

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
		select d.SerialName, d.SerialDescription, @MyCompanyName as MyCompanyName, @MyAddress as MyCompanyAddress,
			@MyTaxCode as MyTaxCode, @MyAccountNo as MyAccountNo, @MyPhoneNo MyPhoneNo, @MyFaxNo MyFaxNo, cast(@NoOfSerial as varchar(2)) as NoOfSerial,
			a.InvName, a.InvNo, a.InvDate, a.FullName, a.CompanyName, a.Address, a.TaxCode, c.InvType, @LogoPath as LogoPath,
			a.ContractNo, a.ContractDate, a.PlaceOfDelivery, a.PlaceOfReceipt, a.BillOfLading, a.ContainerNo, a.TransportCompanyName,
			a.AccountNo, e.Name as PaymentMeans, a.TaxPercent, a.Amount, a.TaxAmount, a.PaymentAmount, a.IsCopy, 
			'Kem theo bang ke' ItemName, '' UOM, 0 Quantity, 0.0 UnitPrice, 0.0 AmountDetail,
			G.Phone1 Phone, G.Fax Fax, f.Address2 ShipToAddress, 
			(select isnull(SUM(Quantity), 0) from VNS_INVOICE_DETAIL where InvID = @InvID) AS MasterQty,
			os.SlpName AS SalesPerson,
			f.NumAtCard AS CustomerPO,
			f.U_UPickSlip AS PickingSlip,
			ISNULL(f.U_UFreight,0) AS Freight,
			ISNULL(f.U_UAdvance,0) AS Advance,
			'' ItemCode, @bangke BangKe,
			TaxUPrice= 0.0,
			AmountDetail2=0.0 ,
			f.PeyMethod,
			@Total9 AS Total9,
			@Total10 AS Total10,
			@Total11 AS Total11,
			@Total12 AS Total12,
			@Total13 As Total13,
			@Total14 AS Total14,
			@Total15 AS Total15,
			AmountInWordsVN=dbo.fsothanhchu(@Total13),
			AmountInWordsEN=dbo.uf_Num_ToEnglishWords(@Total13) --+ ' VietNam Dong'
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
	declare @UOM as nvarchar(100)
	select @UOM = T3.unitMsr
	from VNS_INVOICE T1 inner join VNS_INVOICE_DETAIL T2 on T1.InvID = T2.InvID
	left join INV1 T3 on T3.DocEntry = T1.DocEntry
	where T1.InvID = @InvID
	
	if ISNULL(@UOM,'') = ''
		begin 
			select @UOM = T3.SalUnitMsr
			from VNS_INVOICE T1 inner join VNS_INVOICE_DETAIL T2 on T1.InvID = T2.InvID
			left join OITM T3 on T3.DocEntry = T1.DocEntry
			where T1.InvID = @InvID
		end
		
	select d.SerialName, d.SerialDescription, @MyCompanyName as MyCompanyName, @MyAddress as MyCompanyAddress,
		@MyTaxCode as MyTaxCode, @MyAccountNo as MyAccountNo, @MyPhoneNo MyPhoneNo, @MyFaxNo MyFaxNo, cast(@NoOfSerial as varchar(2)) as NoOfSerial,
		a.InvName, a.InvNo, a.InvDate, a.FullName, a.CompanyName, a.Address, a.TaxCode, c.InvType, @LogoPath as LogoPath,
		a.ContractNo, a.ContractDate, a.PlaceOfDelivery, a.PlaceOfReceipt, a.BillOfLading, a.ContainerNo, a.TransportCompanyName,
		a.AccountNo, e.Name as PaymentMeans, a.TaxPercent, a.Amount, a.TaxAmount, a.PaymentAmount, a.IsCopy, 
		b.ItemName, 'Pcs' UOM, ISNULL(b.Quantity,0) AS Quantity, ISNULL(b.UnitPrice,0) AS UnitPrice, ISNULL(b.Amount,0) as AmountDetail,
		G.Phone1 Phone, G.Fax Fax, f.Address2 ShipToAddress, 
		(select isnull(SUM(Quantity), 0) from VNS_INVOICE_DETAIL where InvID = @InvID) AS MasterQty,
		os.SlpName AS SalesPerson,
		f.NumAtCard AS CustomerPO,
		f.U_UPickSlip AS PickingSlip,
		ISNULL(f.U_UFreight,0) AS Freight,
		ISNULL(f.U_UAdvance,0) AS Advance,
		(SELECT top 1 ItemCode FROM INV1 WHERE INV1.DocEntry = f.DocEntry AND INV1.Dscription = b.ItemName) ItemCode,@bangke BangKe,
		TaxUPrice=ISNULL(b.UnitPrice,0) + (ISNULL(b.UnitPrice,0)*ISNULL(a.TaxPercent,0))/100,--ISNULL(b.UnitPrice,0)*(1+ISNULL(a.TaxPercent,0)/100),
		AmountDetail2=ISNULL(b.Quantity,0)*ISNULL(b.UnitPrice,0) + (ISNULL(b.Quantity,0)*ISNULL(round(b.UnitPrice,1),0)*ISNULL(a.TaxPercent,0))/100, --(ISNULL(b.UnitPrice,0)*(1+ISNULL(a.TaxPercent,0))/100)*ISNULL(b.Quantity,0),
		f.PeyMethod,
		@Total9 AS Total9,
		@Total10 AS Total10,
		@Total11 AS Total11,
		@Total12 AS Total12,
		@Total13 As Total13,
		@Total14 AS Total14,
		@Total15 AS Total15,
		AmountInWordsVN=dbo.fsothanhchu(@Total13),
		AmountInWordsEN=dbo.uf_Num_ToEnglishWords(@Total13) --+ ' VietNam Dong'
	--	h.VatPrcnt TaxPercentDetail, h.VatSum TaxDetail
		
	 from VNS_INVOICE a inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
	inner join  VNS_INVOICE_SETUP c on a.InvName = c.InvName
	inner join VNS_SERIAL d on c.ID = d.IDSetup
	left join [@VNS_PAYMENT_MEANS] e on a.PaymentMeans = e.Code
	LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
	LEFT JOIN OCRD G ON G.CardCode = f.CardCode
	LEFT JOIN OSLP os ON os.EmpID=f.SlpCode

	where a.InvID = @InvID

return (0)

--sp_help vns_invoice