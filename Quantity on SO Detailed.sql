/*
Debug Variables
DECLARE @PartNo VARCHAR(36) = 'GL060.-.-';     
DECLARE @PartNoSuffix VARCHAR(36) = '0000'; 
DECLARE @LocationID VARCHAR(6) = 'MAIN';  
*/

SELECT *
FROM
(
    SELECT 
        od.PlanDate, 
        o.ReqDate, 
        o.OrderNumber, 
        od.LineItem, 
        od.SubLineItem, 
        o.CustomerRef, 
        o.PONumber,
        dbo.ufn_partFormatPart(od.PartNo, od.PartNoSuffix, 0) AS Part, 
        mpl.[Description],
        iodq.QuantityOnSalesOrder AS SOQty,
        -- Adjusted IsOnHold and IsAcknowledged columns
        CASE WHEN o.[Status] = 0 THEN 'On Hold' ELSE NULL END AS IsOnHold,
        CASE WHEN o.AckDate IS NOT NULL THEN 'Acknowledged' ELSE 'Unacknowledged' END AS IsAcknowledged
    FROM Orders o
    JOIN OrderDetail od ON o.oKey = od.oKey
    JOIN MasterPartList mpl ON mpl.MasterPartNo = od.PartNo AND mpl.PartNoSuffix = od.PartNoSuffix
    JOIN uvw_InventoryOrderDetailQuantities iodq ON od.odKey = iodq.odKey
    WHERE 
        iodq.PartNo = @PartNo 
        AND iodq.PartNoSuffix = @PartNoSuffix 
        AND iodq.LocationID = @LocationID 
        AND od.AlternativeODKey IS NULL

    UNION ALL

    SELECT 
        od.PlanDate, 
        o.ReqDate, 
        o.OrderNumber, 
        od.LineItem, 
        od.SubLineItem, 
        o.CustomerRef, 
        o.PONumber,
        dbo.ufn_partFormatPart(od.PartNo, od.PartNoSuffix, 0) AS Part, 
        mpl2.[Description],
        SUM(ids.IssuePartQty) AS SOQty,
        CASE WHEN o.[Status] = 0 THEN 'On Hold' ELSE NULL END AS IsOnHold,
        CASE WHEN o.AckDate IS NOT NULL THEN 'Acknowledged' ELSE 'Unacknowledged' END AS IsAcknowledged
    FROM InventoryDetailSerialized ids
    JOIN MasterPartList mpl ON mpl.[GUID] = ids.IssuePartGUID
    JOIN OrderDetail od ON od.SerialNumber = ids.SerialNumber
    JOIN MasterPartList mpl2 ON mpl2.MasterPartNo = od.PartNo AND mpl2.PartNoSuffix = od.PartNoSuffix
    JOIN InventoryResults ir ON ir.odKey = od.odKey
    JOIN Orders o ON o.oKey = od.oKey
    WHERE 
        ids.Status = 1
        AND mpl.MasterPartNo = @PartNo 
        AND mpl.PartNoSuffix = @PartNoSuffix 
        AND ids.LocationID = @LocationID
        AND o.ClosedDate = '' 
        AND o.Cancelled = 0 
        AND ir.CompleteQty < ir.TotalQty 
        AND od.ItemType = 4 
        AND o.OrderType IN (1, 4)
    GROUP BY 
        od.PlanDate, 
        o.ReqDate, 
        o.OrderNumber, 
        od.LineItem, 
        od.SubLineItem, 
        o.CustomerRef, 
        o.PONumber,
        od.PartNo, 
        od.PartNoSuffix, 
        mpl2.[Description], 
        o.[Status], 
        o.AckDate

    UNION ALL

    SELECT 
        od.PlanDate, 
        o.ReqDate, 
        o.OrderNumber, 
        od.LineItem, 
        od.SubLineItem, 
        o.CustomerRef, 
        o.PONumber,
        dbo.ufn_partFormatPart(od.PartNo, od.PartNoSuffix, 0) AS Part, 
        mpl2.[Description],
        COUNT(1) AS SOQty,
        CASE WHEN o.[Status] = 0 THEN 'On Hold' ELSE NULL END AS IsOnHold,
        CASE WHEN o.AckDate IS NOT NULL THEN 'Acknowledged' ELSE 'Unacknowledged' END AS IsAcknowledged
    FROM InventoryDetailSerialized ids
    JOIN MasterPartList mpl ON mpl.[GUID] = ids.SecondaryIssuePartGUID
    JOIN OrderDetail od ON od.SerialNumber = ids.SerialNumber
    JOIN MasterPartList mpl2 ON mpl2.MasterPartNo = od.PartNo AND mpl2.PartNoSuffix = od.PartNoSuffix
    JOIN InventoryResults ir ON ir.odKey = od.odKey
    JOIN Orders o ON o.oKey = od.oKey
    WHERE 
        ids.Status = 1
        AND mpl.MasterPartNo = @PartNo 
        AND mpl.PartNoSuffix = @PartNoSuffix 
        AND ids.LocationID = @LocationID
        AND o.ClosedDate = '' 
        AND o.Cancelled = 0 
        AND ir.CompleteQty < ir.TotalQty 
        AND od.ItemType = 4 
        AND o.OrderType IN (1, 4)
    GROUP BY 
        od.PlanDate, 
        o.ReqDate, 
        o.OrderNumber, 
        od.LineItem, 
        od.SubLineItem, 
        o.CustomerRef, 
        o.PONumber,
        od.PartNo, 
        od.PartNoSuffix, 
        mpl2.[Description], 
        o.[Status], 
        o.AckDate
) tmp
WHERE tmp.SOQty <> 0
ORDER BY tmp.PlanDate;
