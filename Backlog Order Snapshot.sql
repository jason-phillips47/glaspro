/*
Debug variables
DECLARE @location VARCHAR(20) = 'MAIN';
DECLARE @startdate DATE = '2024-05-01';
DECLARE @enddate DATE = '2024-08-05';
DECLARE @UomTypeWeight TINYINT = 255;
DECLARE @PriceTypeArea TINYINT = 4;
DECLARE @sysUnitSet INT;
*/

SELECT @sysUnitSet = Value
FROM GeneralSetup
WHERE Parameter LIKE 'dbSystemEngineeringUnitSet';

-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#OrdersOpen') IS NOT NULL
    DROP TABLE #OrdersOpen;

-- Create the temporary table with the necessary columns
CREATE TABLE #OrdersOpen (
    OrderDate SMALLDATETIME,
    OrderNumber VARCHAR(50),
    CompleteDate SMALLDATETIME,
    OrderType VARCHAR(100),
    TargetShipDate DATE,
    ReqDate DATE,
    Customer VARCHAR(255),
    SalesPerson VARCHAR(255),
    OrderTotal DECIMAL(18,2),
    CultureInfo VARCHAR(50)
);

DECLARE @filter INT = 0;
DECLARE @displayack BIT = 0;
DECLARE @CostingCurrency VARCHAR(20) = 'en-US';
DECLARE @category INT = 0;

-- Insert the stored procedure results into the temporary table
IF @category = 0
    INSERT INTO #OrdersOpen
    EXEC uspx_biSelectOrdersOpen @startdate, @enddate, @filter, @displayack, @location, @CostingCurrency;
ELSE
    INSERT INTO #OrdersOpen
    EXEC usp_biSelectOrdersOpenByCatDetailed @startdate, @enddate, @filter, @displayack, @location, @category, @CostingCurrency;

-- Main Orders CTE
WITH MainOrdersCTE AS (
    SELECT 
        o.oKey,
        o.OrderNumber,
        DATEPART(year, o.Date) AS [year], 
        DATEPART(month, o.Date) AS [monthshort], 
        DATENAME(m, o.Date) AS [month], 
        o.Date,
        o.ShipDate,
        o.Status,
        oo.TargetShipDate,
        -- Compute statusName based on o.Status
        CASE
            WHEN o.Status = 0 THEN 'On Hold'
            WHEN o.Status = 1 THEN 'Available'
            WHEN o.Status = 3 THEN 'Released'
            ELSE 'Unknown'
        END AS statusName,
        dbo.ufn_tmGet(ot.Description) AS OrderType, 
        c.Name, 
        c.SiteName, 
        o.CustomerRef, 
        o.PONumber, 
        o.OrderContact, 
        ([dbo].[ufn_orderGetTotalPrice](o.oKey) * o.CurrencyMultiplier) AS TotalPrice, 
        o.TaxAmount, 
        CASE 
            WHEN UPPER(ot.Description) = 'CREDIT' THEN 
                -[dbo].[ufn_orderGetTotalPrice](o.oKey) * o.CurrencyMultiplier 
            ELSE 
                [dbo].[ufn_orderGetTotalPrice](o.oKey) * o.CurrencyMultiplier 
        END AS ActualPrice, 
        COUNT(od.odKey) AS LineItems, 
        dbo.ufn_employeesFormatName(e.LastName, e.FirstName) AS EmployeeName, 
        dbo.ufn_employeesFormatName(sp.LastName, sp.FirstName) AS SalesPersonName, 
        o.Notes, 
        o.Terms, 
        ISNULL(c2.SiteName, '') AS ProjectName,
        o.CompleteDate
    FROM 
        Orders o
        INNER JOIN OrderTypes ot ON ot.OrderType = o.OrderType
        INNER JOIN Customers c ON c.CustomerID = o.CustomerID AND c.SiteID = o.SiteID
        LEFT JOIN Customers c2 ON o.ProjectGUID = c2.CustomerGUID
        LEFT JOIN OrderDetail od ON od.oKey = o.oKey AND od.ItemType <> 5 AND od.AlternativeODKey IS NULL
        LEFT JOIN Employees e ON e.EmployeeID = o.EnteredBy
        LEFT JOIN Employees sp ON sp.EmployeeID = o.SalesPersonID
        LEFT JOIN #OrdersOpen oo ON o.OrderNumber = oo.OrderNumber  -- Joining to get TargetShipDate
    WHERE 
        (@location IS NULL OR e.LocationID = @location) 
        AND o.OrderType IN (1, 3)
        AND o.Date >= @startdate 
        AND o.Date < DATEADD(d, 1, @enddate)
        AND NOT EXISTS (
            SELECT 1 
            FROM OrderRelations 
            WHERE ChildoKey = o.oKey AND RelationType = 2
        )
        -- Filter orders based on #OrdersOpen
        AND o.OrderNumber IN (SELECT OrderNumber FROM #OrdersOpen)
    GROUP BY 
        o.oKey,
        o.OrderNumber,
        DATEPART(year, o.Date), 
        DATEPART(month, o.Date), 
        DATENAME(m, o.Date), 
        o.Date, 
        o.ShipDate,
        o.Status,
        oo.TargetShipDate,
        CASE
            WHEN o.Status = 0 THEN 'On Hold'
            WHEN o.Status = 1 THEN 'Available'
            WHEN o.Status = 3 THEN 'Released'
            ELSE 'Unknown'
        END,
        ot.Description, 
        c.Name, 
        c.SiteName, 
        o.CustomerRef, 
        o.PONumber, 
        o.OrderContact, 
        [dbo].[ufn_orderGetTotalPrice](o.oKey), 
        e.LastName, 
        e.FirstName, 
        sp.LastName, 
        sp.FirstName, 
        o.Notes, 
        o.CurrencyMultiplier, 
        o.TaxAmount, 
        o.Terms, 
        c2.SiteName,
        o.CompleteDate
),
-- Other CTEs remain the same
-- (IncQuantityCTE, StatusCTE, InvoiceOrderSubtotals, InvoiceSubtotals, InvoiceOrderAmounts, InvoiceAmounts, OrderSubtotals, OrderFactors, OrderTotals)

-- Final SELECT Statement
SELECT
    mo.*,
    iq.IncQuantity AS TotalIncQuantity,
    sc.Status,
    ia.InvoiceAmount,
    CASE 
        WHEN ia.InvoiceAmount IS NULL THEN ot.Subtotal 
        ELSE NULL 
    END AS Subtotal,
    ot.TotalDimensions,
    ot.QtyTotal,
    ot.ItemTotal,
    ot.OrderWeight,
    ot.DecimalPlaces,
    ot.CultureInfo,
    ot.UOM
FROM
    MainOrdersCTE mo
    LEFT JOIN IncQuantityCTE iq ON iq.oKey = mo.oKey
    LEFT JOIN StatusCTE sc ON sc.oKey = mo.oKey
    LEFT JOIN InvoiceAmounts ia ON ia.oKey = mo.oKey
    LEFT JOIN OrderTotals ot ON ot.oKey = mo.oKey
ORDER BY mo.Date;

-- Drop the temporary table
DROP TABLE #OrdersOpen;
