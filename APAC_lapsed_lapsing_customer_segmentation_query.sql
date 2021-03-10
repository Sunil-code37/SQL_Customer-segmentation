	--Transactional data
--drop table #b
Select  c.contactkey, documentdtkey, OrderNumber, GBPCurrencyTurnover into #temp 

from [CDW].[dbo].[Contact_Base] as c
JOIN [CDW].[dbo].[Shipment_Invoice_Line] as s
ON s.ContactKey = c.ContactKey
JOIN CDW.dbo.BusinessUnit_Base b
ON s.BusinessUnitKey =	b.BusinessUnitKey


WHERE       s.endcustomersale = 1
AND         b.SourceSystemID = 'FAR'                            
AND         b.BusinessUnitKey <> 27                                                 -- Exclude CPC
AND         b.ParentBusinessUnitCode != 'GB1'         
AND			s.documentdtkey > 20180415



--drop table #temp1
--Aggregation

Select #temp.ContactKey, max(documentdtkey) as LOD, COUNT(distinct OrderNumber) as Orders, SUM(GBPCurrencyTurnover) as Sales
  into #temp1
from #temp
group by #temp.ContactKey
having SUM(GBPCurrencyTurnover)>0

--Based on browsing
--Drop table #brows1
Select r.ContactKey, Datekey into #b
from marketing.dbo.MA_OM_Traffic_APAC as t
JOIN cdw.dbo.WCUserRegistration_Base as r
ON r.usersid = t.usersid
where Datekey > 20200405 


--Delete from #brows where DocumentDTKey > 

--drop table #brows

-- Aggregation

Select ContactKey, max(Datekey) as LBD into #brows
from #b
group by Contactkey

Select #brows.ContactKey, LBD, LOD, Orders, Sales  into #brows1 from #brows
LEFT JOIN #temp1
ON #brows.ContactKey = #temp1.contactkey


Delete from #brows1 
  where LOD >  20200405

Delete from #temp1 where LOD > 20191215 


--combining both the tables

--drop table #temp3
Select case when t.ContactKey IS NULL then #brows1.ContactKey
		else t.ContactKey end as Ckey, t.LOD, LBD,
		case when t.Orders IS NULL then #brows1.Orders
		else t.Orders end as corders,
		case when t.Sales IS NULL then #brows1.Sales
		else t.Sales end as Csales,
case when  t.LOD between 20191115 and 20200115 then 'Lapsing' 
	 when  t.LOD between 20190515 and 20191115 then 'Lapsed(7-12)'
	 when t.LOD between 20180515 and 20190515 then 'Lapsed(13-24)'
	 else 'Others' end as Status,
 case when LBD between 20200424 and 20200508 then 'Browse < 2 weeks'
	  when LBD between 20200409 and 20200423 then 'Browse (2-4) weeks'
	  else 'No Browse' end as Brows
 
into #temp3
from #temp1 as t 
Full Outer JOIN #brows1
on t.ContactKey = #brows1.ContactKey

 
--drop table #temp4

Select CKey,Status, Brows, corders, csales, 
case when corders = 1 then 'One time' 
	 when corders > 1 and corders < 6 then 'Low frequency (2-5 orders)'
	 when corders > 5 and corders < 16 then 'Mid frequency (6-15 orders)'
	when corders > 16 and corders <= 50 then 'High frequency (16-50 orders)'
	else 'Very High frequency(More than 50 orders)' end as Orderfrequency,
	
case when cSales <= 10 then 'Very Low Spenders(0-10)'
	when cSales >10 and cSales <= 25 then  'Low Spenders(�11-�25)'
	when cSales >25 and cSales <= 50 then  'Mid Spenders(�26-�50)'
	when cSales >10 and cSales <= 500 then  'High Spenders(�51-�500)'
	else 'very High Spenders(More than �500)' end as Salesbucket,
case when Email_Perm =1 and ValidEmail =1 then 'Yes' else 'No' end as EmailPermission,
case when ValidTel = 1 and Tel_Perm =1 then 'Yes' else 'No' end as TelPermission,
 Region, m.AccountManager, m.CorporateNo, m.Discount, a.DiscountProfileCode
into #temp4

from #temp3
JOIN ma.SingleCustomerView as m
ON #temp3.ckey = m.ContactKey
JOIN [CDW].[dbo].[Account_Base] as a
ON m.accountkey = a.AccountKey 

--drop table #temp5

--Select Region, AVG

Select * into #temp5 from #temp4

--Exclusions

Delete  from #temp5

	where --corporateNo  'Unspecified'
	 Discount = 1
	or Accountmanager in ('reseller','Wholesale','Wholesaler') or 
	(DiscountProfileCode <> 'Unspecified' and DiscountProfileCode not like '%00')

Select * from #temp5