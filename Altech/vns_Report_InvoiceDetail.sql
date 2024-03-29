
GO
/****** Object:  StoredProcedure [dbo].[vns_Report_InvoiceDetail]    Script Date: 05/21/2012 10:50:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Amonut = Tien hang chua VAT
--DiscountNoVAT Tien chiet khau chyu VAT
-- TotalNoVAT Tong gia tri hoa don chua VAT
-- TacAmount Tong thue gia tri gia tang
-- TotalVAT So tien hoa don chua VAt
-- AmountDetail(Thanh tien) = So luong  * Don gia
--[dbo].[vns_Report_InvoiceDetail] 1817

alter Procedure [dbo].[vns_Report_InvoiceDetail]
	@DocKey int
As
begin
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
	 where a.DocEntry= @DocKey

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
		select	top 1 @DocType = DocType,
				@MyTaxCode = IsNull(MyTaxCode, ''),
				@WhsCode = IsNull(WhsCode, ''),
				@ItemType = IsNull(ItemType, 0)
		  from VNS_INVOICE where DocEntry = @DocKey

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
		@Total10=SUM(ISNULL(CAST(f.U_UFreight as int),0)),
		@Total11=SUM(ISNULL(CAST(f.U_UFreight as int),0)*(1+(a.TaxPercent/100))),
		@Total12=SUM(((ISNULL(b.UnitPrice,0)+ISNULL(CAST(f.U_UFreight as int),0))*a.TaxPercent)/100),
		@Total14=SUM(ISNULL(CAST(f.U_UAdvance as int),0))
	FROM VNS_INVOICE a inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
		LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
	where a.DocEntry = @DocKey

	SELECT 
		@Total9=SUM((ISNULL(b.UnitPrice,0)*(1+ISNULL(a.TaxPercent,0)/100))*ISNULL(b.Quantity,0)),
		@Total13=SUM((ISNULL(b.UnitPrice,0)*(1+ISNULL(a.TaxPercent,0)/100))*ISNULL(b.Quantity,0))+ISNULL(@Total11,0)
	FROM VNS_INVOICE a inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
		LEFT JOIN OINV f ON f.DocEntry = a.DocEntry
	where a.DocEntry = @DocKey

	SET @Total15=ISNULL(@Total13,0)-ISNULL(@Total14,0)

	declare @bangke nvarchar(15)
	set @bangke = ''

	select @bangke = isnull(T1.U_UBangKe,'0') from VNS_INVOICE T0
		left join OINV T1 on T1.DocEntry = T0.DocEntry
	where T0.DocEntry = @DocKey

	-- out report
	select row_number() over (partition by d.SerialName order by (select 1)) as Stt, d.SerialName, d.SerialDescription, @MyCompanyName as MyCompanyName, @MyAddress as MyCompanyAddress,
		@MyTaxCode as MyTaxCode, @MyAccountNo as MyAccountNo, @MyPhoneNo MyPhoneNo, @MyFaxNo MyFaxNo, cast(@NoOfSerial as varchar(2)) as NoOfSerial,
		a.InvName, a.InvNo as InvNo, f.U_UBangke as BkNo, a.InvDate, a.FullName, a.CompanyName, a.Address, a.TaxCode, c.InvType, @LogoPath as LogoPath,
		a.ContractNo, a.ContractDate, a.PlaceOfDelivery, a.PlaceOfReceipt, a.BillOfLading, a.ContainerNo, a.TransportCompanyName,
		a.AccountNo, e.Name as PaymentMeans, a.TaxPercent, (f.DocTotal - f.VatSum + f.DiscSum) as Amount, a.TaxAmount, a.PaymentAmount, a.IsCopy, 
		case when @bangke = '0' then 'Khong phai hoa don kem bang ke' else f1.Dscription end as ItemName,
		case when isnull(f1.unitMsr,'') <> '' then f1.unitMsr
	
		ELSE (select top 1 T3.SalUnitMsr
				from VNS_INVOICE T1
				inner join VNS_INVOICE_DETAIL T2 on T1.InvID = T2.InvID
				left join INV1 t4 ON t4.DocEntry = T1.DocEntry AND T4.Dscription = T2.ItemName
				left join OITM T3 on T4.ItemCode = T3.ItemCode
				where t4.DocEntry  = @DocKey )
			
		end as UOM,
		ISNULL(f1.Quantity,0) AS Quantity, ISNULL((f1.Price),0) AS UnitPrice, ISNULL(f1.LineTotal,0) as AmountDetail,
		G.Phone1 Phone, G.Fax Fax, f.Address2 ShipToAddress, 
		--(select isnull(SUM(Quantity), 0) from VNS_INVOICE_DETAIL where InvID = @InvID) AS MasterQty,
		(select isnull(SUM(Quantity), 0) 
			from VNS_INVOICE a
			left join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
			where a.docentry = @DocKey
			) as MasterQty,
		os.SlpName AS SalesPerson,
		f.NumAtCard AS CustomerPO,
		f.U_UPickSlip AS PickingSlip,
		ISNULL(f.U_UFreight,0) AS Freight,
		ISNULL(f.U_UAdvance,0) AS Advance,
		(SELECT top 1 ItemCode FROM INV1 WHERE INV1.DocEntry = f.DocEntry AND INV1.Dscription = f1.Dscription) ItemCode,
		TaxUPrice=ISNULL(f1.Price,0)*(1+ISNULL(a.TaxPercent,0)/100),
		AmountDetail2=(ISNULL(f1.Price,0)*(1+ISNULL(a.TaxPercent,0)/100))*ISNULL(f1.Quantity,0),
		f.PeyMethod,
		f.U_UBangke DetailNo,
		@Total9 AS Total9,
		@Total10 AS Total10,
		@Total11 AS Total11,
		@Total12 AS Total12,
		@Total13 As Total13,
		@Total14 AS Total14,
		@Total15 AS Total15,
		AmountInWordsVN=dbo.fsothanhchu(@Total13),
		AmountInWordsEN=dbo.uf_Num_ToEnglishWords(@Total13) --+ ' VietNam Dong'
		
		,f.DiscSum as DiscountNoVAT,
		(ISNULL((f.DocTotal - f.VatSum + f.DiscSum),0)-ISNULL(f.DiscSum,0)) as TotalNoVAT, -- tong gia tri hoa don chua VAT
		(a.TaxAmount+(ISNULL((f.DocTotal - f.VatSum + f.DiscSum),0)-ISNULL(f.DiscSum,0))) as TotalVAT
		
	--	h.VatPrcnt TaxPercentDetail, h.VatSum TaxDetail
	into #Temp	
	from VNS_INVOICE a --inner join VNS_INVOICE_DETAIL b on a.InvID = b.InvID
		left join  VNS_INVOICE_SETUP c on a.InvName = c.InvName
		left join VNS_SERIAL d on c.ID = d.IDSetup
		left join [@VNS_PAYMENT_MEANS] e on a.PaymentMeans = e.Code
		left JOIN OINV f ON f.DocEntry = a.DocEntry
		left join INV1 f1 on f.DocEntry = f1.DocEntry
		LEFT JOIN OCRD G ON G.CardCode = f.CardCode
		LEFT JOIN OSLP os ON os.EmpID=f.SlpCode	
	where a.DocEntry = @DocKey and a.DocType = 13 and @bangke <> '0'
	
	if @bangke = '0' or @@ROWCOUNT = 0
		insert #Temp (ItemName, Quantity, UnitPrice, AmountDetail, Freight, Advance) 
			values (N'Hoa don khong kem bang ke', 0, 0, 0, 0, 0)
	select * from 	#Temp
end