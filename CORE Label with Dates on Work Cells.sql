/*
Debug Variables
DECLARE @guid uniqueidentifier = NULL
DECLARE @schedule int=30570
DECLARE @startbatch int=1
DECLARE @endbatch int=1
DECLARE @report varchar(20)='L-GLASS'
DECLARE @unit int
DECLARE @bin varchar(6)
DECLARE @order varchar(20)
DECLARE @item int
DECLARE @liteAttribute varchar(255)='LITE'
DECLARE @logoAttribute varchar(255)='LOGO'
-- End Debug
*/

IF OBJECT_ID('tempdb..#LabelParts') IS NOT NULL DROP TABLE #LabelParts
CREATE TABLE #LabelParts (ReportID varchar(16), ReportDesc varchar(50), DisplayFractions bit, BinSource tinyint, DisplayCallSize bit, ReleaseDate smalldatetime, SchedID int, ScheduleDesc varchar(50), WorkRouteAttrValue varchar(255), WorkRouteDesc varchar(20), 
	BatchID smallint, BatchDesc varchar(50), oKey int, odKey int, Customer nvarchar(256), OrderNumber varchar(20), OrderItem smallint, OrderItemSubLineItem smallint, PONumber nvarchar(20), CustomerRef nvarchar(50), ReqDate smalldatetime, TargetShipDate smalldatetime, PackingType nvarchar(20), PackingNote nvarchar(50), 
	UnitID smallint, MasterKey int, ParentKey int, Barcode varchar(50), PartNo varchar(35), PartNoSuffix varchar(4), PartDesc nvarchar(100), Quantity smallint, Width real, Height real, Thickness real, Weight real,
	OverallPartNo varchar(35), OverallPartNoSuffix varchar(4), OverallPartDesc nvarchar(100), OverallWidth real, OverallHeight real, OverallThickness real, OverallCallSize varchar(13), 
	DisplayWidth real, DisplayHeight real, DisplayThickness real, 
	WorkFlow varchar(255), RackSort int, RackType int, RackID varchar(20), StackID nvarchar(5), Slot int, SubSlot int, Bin varchar(5), SecondaryBin varchar(5), GlassID smallint, 
	Options nvarchar(4000), Attributes varchar(1000), PartTypes nvarchar(1000), Notes varchar(255), Notes1 varchar(255), 
	CustomerID varchar(16), SiteID varchar(16), Name nvarchar(100), SiteName nvarchar(100), ShpAddr_CompanyName nvarchar(100), [Route] nvarchar(20), 
	OrderItemQty smallint, OrderItemXofItemQty smallint, OrderItemXofOrderQty smallint, OrderQty smallint, Misc varchar(255), 
	OrdersUserDef1 varchar(50), OrdersUserDef2 varchar(50), OrdersUserDef3 varchar(50), OrdersUserDef4 varchar(50), OrdersUserDef5 varchar(50),
	OrdersUserDef6 varchar(50), OrdersUserDef7 varchar(50), OrdersUserDef8 varchar(50), OrdersUserDef9 varchar(50), OrdersUserDef10 varchar(50),
	CustomersUserDef1 varchar(50), CustomersUserDef2 varchar(50), CustomersUserDef3 varchar(50), CustomersUserDef4 varchar(50), CustomersUserDef5 varchar(50),
	CustomersUserDef6 varchar(50), CustomersUserDef7 varchar(50), CustomersUserDef8 varchar(50), CustomersUserDef9 varchar(50), CustomersUserDef10 varchar(50),
	InvLocation varchar(50), PreShippingRack varchar(16), PreShippingStackID nvarchar(5), PreShippingSlot smallint, PreShippingSubSlot smallint, ShippingContainerID varchar(16), MullContainerKey int, ServerDate datetime, StartingSchedule int, StartingUnit smallint, Thumbnail image, Remake int default 0)

IF @guid IS NOT NULL
BEGIN
	--Called from Opti.  You must customize this and supply a report ID here.
	DECLARE @LabelName VARCHAR(255)
	DECLARE @SQL nvarchar(max)
	DECLARE @FVMaster sysname
	SET @LabelName= 'L-GLASS'

	SET @FVMaster=dbo.ufn_FVMasterDatabase()
	--Statement to execute for remake/regular should be the same procedure, just different report IDs and temp table source.
	SET @SQL='
	
	
	INSERT INTO #LabelParts (ReportID, ReportDesc, DisplayFractions, BinSource, DisplayCallSize, ReleaseDate, SchedID, ScheduleDesc, WorkRouteAttrValue, WorkRouteDesc, 
		BatchID, BatchDesc, oKey, odKey, Customer, OrderNumber, OrderItem, OrderItemSubLineItem, PONumber, CustomerRef, ReqDate, TargetShipDate, PackingType, PackingNote,
		UnitID, MasterKey, ParentKey, Barcode, PartNo, PartNoSuffix, PartDesc, Quantity, Width, Height, Thickness, Weight,
		OverallPartNo, OverallPartNoSuffix, OverallPartDesc, OverallWidth, OverallHeight, OverallThickness, OverallCallSize, 
		DisplayWidth, DisplayHeight, DisplayThickness , 
		WorkFlow, RackSort, RackType, RackID, StackID, Slot, SubSlot, Bin, SecondaryBin, GlassID , 
		Options, Attributes, PartTypes, Notes, Notes1, 
		CustomerID, SiteID, Name, SiteName, ShpAddr_CompanyName, [Route], 
		OrderItemQty, OrderItemXofItemQty, OrderItemXofOrderQty, OrderQty, Misc, 
		OrdersUserDef1, OrdersUserDef2, OrdersUserDef3, OrdersUserDef4, OrdersUserDef5,
		OrdersUserDef6, OrdersUserDef7, OrdersUserDef8, OrdersUserDef9, OrdersUserDef10,
		CustomersUserDef1, CustomersUserDef2, CustomersUserDef3, CustomersUserDef4, CustomersUserDef5,
		CustomersUserDef6, CustomersUserDef7, CustomersUserDef8, CustomersUserDef9, CustomersUserDef10,
		InvLocation, PreShippingRack, PreShippingStackID, PreShippingSlot, PreShippingSubSlot, ShippingContainerID, MullContainerKey, ServerDate, StartingSchedule, StartingUnit, Thumbnail)
		EXEC ' + @FVMaster + '..[usp_prodReportSelectWorkRoute] -1, NULL, NULL, @LabelName, NULL, NULL, NULL, NULL, #TempProdDetails'
	
	--Work route report can work off of MK, PK parts if you give it the reject reprocessing temporary table.
	IF OBJECT_ID('tempdb..#TempProdDetails') IS NOT NULL DROP TABLE #TempProdDetails
	CREATE TABLE #TempProdDetails (SchedID int, UnitID int, MasterKey int, ParentKey int, 
		PRIMARY KEY(SchedID, UnitID, MasterKey, ParentKey))
	
	IF EXISTS(SELECT 1 FROM OptiReportLites WHERE SessionGUID=@guid AND ProdType IN (0,2,3,10,20)) BEGIN
		SET @LabelName= 'L-GLASS' --'L-RECUT' --Includes all glass parts.
		
		INSERT INTO #TempProdDetails SELECT DISTINCT SchedID, UnitID, MasterKey, ParentKey FROM OptiReportLites WHERE SessionGUID=@guid AND ProdType IN (0,2,3,10,20)
		
		--Call the work route procedure on FVMaster to insert data into temp table.
		EXEC sp_executesql @SQL, N'@LabelName varchar(16)', @LabelName
		
		--Clear working table for next pass.
		DELETE FROM #TempProdDetails
	END
	
	--Remake label prints for all glass, has glass part assigned globally.
	IF EXISTS(SELECT 1 FROM OptiReportLites WHERE SessionGUID=@guid AND ProdType=1) BEGIN
		SET @LabelName='L-GLASS'--'L-RECUT' --Includes all glass parts for remakes.
		INSERT INTO #TempProdDetails SELECT SchedID, UnitID, MasterKey, ParentKey FROM OptiReportLites WHERE SessionGUID=@guid AND ProdType=1
		
		EXEC sp_executesql @SQL, N'@LabelName varchar(16)', @LabelName
		
		--Flag as a remake if ProdType=1.
		UPDATE lp 
			SET lp.remake=1 
			FROM #LabelParts lp	
			INNER JOIN OptiReportLites olRDL ON lp.SchedID=olRDL.SchedID AND lp.UnitID=olRDL.UnitID AND lp.MasterKey=olRDL.MasterKey AND lp.ParentKey=olRDL.ParentKey
			WHERE olRDL.SessionGUID=@guid AND olRDL.ProdType=1
	END
	
	--Rejoin the original Opti table with the sequence field to return labels in proper sequence.
	--Min(Sequence) is done in case the report is configured by ordered part instead of glass part, so that the masterkey/parentkey in the output does not have to match what's in OptiReportLites.
	--ReleaseID is appended 
	SELECT 
    DistinctRows.*
	FROM (
	SELECT DISTINCT x.Sequence, ReportID, ReportDesc, DisplayFractions, BinSource, DisplayCallSize, ReleaseDate, x.SchedID, ScheduleDesc, WorkRouteAttrValue, WorkRouteDesc, 
		BatchID, BatchDesc, x.oKey, x.odKey, Customer, x.OrderNumber, OrderItem, OrderItemSubLineItem, x.PONumber, x.CustomerRef, x.ReqDate, TargetShipDate,  x.PackingType, PackingNote,
    x.UnitID, x.MasterKey, x.ParentKey, x.Barcode, x.PartNo, x.PartNoSuffix, PartDesc, x.Quantity, x.Width, x.Height, x.Thickness, x.Weight,
    OverallPartNo, OverallPartNoSuffix, OverallPartDesc, OverallWidth, OverallHeight, OverallThickness, OverallCallSize,
    x.DisplayWidth, x.DisplayHeight, x.DisplayThickness ,
    WorkFlow, RackSort, RackType, RackID, StackID, Slot, SubSlot, Bin, SecondaryBin, GlassID ,
    Options, Attributes, PartTypes, x.Notes, Notes1,
    x.CustomerID, x.SiteID, Name, SiteName, x.ShpAddr_CompanyName, [Route],
    OrderItemQty, OrderItemXofItemQty, OrderItemXofOrderQty, OrderQty, x.Misc, 
		OrdersUserDef1, OrdersUserDef2, OrdersUserDef3, OrdersUserDef4, OrdersUserDef5,
		OrdersUserDef6, OrdersUserDef7, OrdersUserDef8, OrdersUserDef9, OrdersUserDef10,
		CustomersUserDef1, CustomersUserDef2, CustomersUserDef3, CustomersUserDef4, CustomersUserDef5,
		CustomersUserDef6, CustomersUserDef7, CustomersUserDef8, CustomersUserDef9, CustomersUserDef10,
		InvLocation, PreShippingRack, PreShippingStackID, PreShippingSlot, PreShippingSubSlot, ShippingContainerID, MullContainerKey, ServerDate, StartingSchedule, StartingUnit, ISNULL(odaLITE.ParamValue, '') AS LiteNumber
		, ISNULL(odaLOGO.ParamValue2, '') AS LogoAttribute
		, o.Comments AS OrderComment
		, o.CustomerRef AS OrderCustomerRef
		, od.Comment AS LIComment
		, od.CustomerRef AS LICustomerRef
		, o.ShpAddr_Comments AS OrderShipComment
		, ISNULL(sc.ShortcutDesc, x.OverallPartDesc) DisplayDesc
		, STUFF((
        SELECT ', ' + wf.Item + ' (' + 
            STUFF((
                SELECT DISTINCT ' & ' + FORMAT(odp3.PlanDate, 'MM-dd')
                FROM [FVMaster].dbo.OrderDetailPlans odp3
                JOIN  [FVMaster].dbo.WorkCells wc3 ON wc3.ID = odp3.WorkCellID
                WHERE odp3.odKey = od.odKey AND (wc3.Description = wf.Item OR (wf.Item = 'CUT' AND wc3.Description = 'CUTTING') OR (wf.Item = 'EDG-PST' AND wc3.Description = 'EDGE-POST') OR (wf.Item = 'BOXING' AND wc3.Description = 'BOXING-QC') OR (wf.Item = 'BO-BEVEL' AND wc3.Description = 'BUY OUT BEVEL') OR (wf.Item = 'CMSSS' AND wc3.Description = 'CMS') OR (wf.Item = 'BO-TEMP' AND wc3.Description = 'BUY OUT TEMP') OR (wf.Item = 'HTSOAK' AND wc3.Description = 'HEATSOAK') OR (wf.Item = 'BO-BEV-PST' AND wc3.Description = 'BUY OUT BEVEL-POST') OR (wf.Item = 'MTR-PST' AND wc3.Description = 'MITER-POST') OR (wf.Item = 'DRL-PST' AND wc3.Description = 'DRILL-POST') OR (wf.Item = 'TDRL-PST' AND wc3.Description = 'TOPDRILL-POST') OR (wf.Item = 'BP-PST' AND wc3.Description = 'BKPNT-POST') OR (wf.Item = 'SNDBLST' AND wc3.Description = 'SANDBLAST') OR (wf.Item = 'D-SNDBLST' AND wc3.Description = 'DEEP SANDBLAST') OR (wf.Item = 'SLKSCREEN' AND wc3.Description = 'SILKSCREEN')) AND (odp3.ParentKey = 0 OR odp3.ParentKey = x.ParentKey)
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')'
        FROM (
            SELECT LTRIM(RTRIM(m.value('.', 'NVARCHAR(MAX)'))) AS Item, rn = ROW_NUMBER() OVER (ORDER BY (SELECT 1))
            FROM (
                SELECT CAST('<M>' + REPLACE(x.WorkFlow, ',', '</M><M>') + '</M>' AS XML) AS Data
            ) AS A
            CROSS APPLY Data.nodes('/M') AS Split(m)
        ) AS wf
        ORDER BY wf.rn
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS PlanDateWorkflow
	FROM (
		SELECT lp.*, t1.ReleaseID, t1.[Sequence]
		FROM #LabelParts lp
		JOIN (SELECT SchedID, UnitID, MasterKey, ParentKey, ReleaseID=MIN(ReleaseID), [Sequence]=MIN([Sequence]) FROM OptiReportLites WHERE SessionGUID=@guid AND ProdType IN (0,2,3,10,20) GROUP BY SchedID, UnitID, MasterKey, ParentKey
				UNION
				SELECT SchedID, UnitID, MasterKey, ParentKey, ReleaseID, [Sequence] FROM OptiReportLites WHERE SessionGUID=@guid AND ProdType=1
		) t1 ON t1.SchedID=lp.SchedID AND t1.UnitID=lp.UnitID AND t1.MasterKey=lp.MasterKey AND t1.ParentKey=lp.ParentKey 
	) x
	LEFT JOIN [FVMaster].dbo.OrderDetailAttributes odaLITE ON odaLITE.odKey=x.odKey 
		AND odaLITE.MasterKey=x.MasterKey AND odaLITE.ParentKey=x.ParentKey
		AND odaLITE.ParamText=@liteAttribute
	LEFT JOIN [FVMaster].dbo.OrderDetailAttributes odaLOGO ON odaLOGO.odKey=x.odKey 
		AND odaLOGO.MasterKey=x.MasterKey AND odaLOGO.ParentKey=x.ParentKey
		AND odaLOGO.ParamText=@logoAttribute
	INNER JOIN [FVMaster].dbo.Orders o ON o.oKey=x.oKey

	INNER JOIN [FVMaster].dbo.OrderDetail od ON od.odkey=x.odkey
	JOIN [FVMaster].dbo.OrderDetailPlans odp ON odp.odKey = od.odKey
	LEFT JOIN [FVMaster].dbo.Shortcuts sc ON sc.odKey=od.odkey) AS DistinctRows
	ORDER BY DistinctRows.[Sequence]
	EXEC sp_executesql @SQL, N'@guid uniqueidentifier, @liteAttribute varchar(100), @logoAttribute varchar(100)', @guid, @liteAttribute, @logoAttribute
END