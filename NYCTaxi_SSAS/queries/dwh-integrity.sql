-- FK_FHV_PickupDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[PickupDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_FHV_DropoffDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[DropoffDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_RequestDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[RequestDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [RequestDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_OnSceneDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[OnSceneDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [OnSceneDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_PickupDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[PickupDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_DropoffDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[DropoffDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_DFS_Date
SELECT COUNT_BIG(*) FROM dbo.[Fact_Daily_Financial_Snapshot] f LEFT JOIN dbo.[Dim_Date] d ON f.[DateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Daily_Financial_Snapshot];
-- FK_ZTS_Date
SELECT COUNT_BIG(*) FROM dbo.[Fact_Zone_Traffic_Snapshot] f LEFT JOIN dbo.[Dim_Date] d ON f.[DateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Zone_Traffic_Snapshot];
-- FK_BPS_Date
SELECT COUNT_BIG(*) FROM dbo.[Fact_Base_Performance_Snapshot] f LEFT JOIN dbo.[Dim_Date] d ON f.[DateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Base_Performance_Snapshot];
-- FK_FYG_PickupDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[PickupDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_DropoffDate
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Date] d ON f.[DropoffDateKey]=d.[DateKey] WHERE d.[DateKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffDateKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FHV_PickupTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[PickupTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_FHV_DropoffTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[DropoffTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_RequestTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[RequestTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [RequestTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_OnSceneTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[OnSceneTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [OnSceneTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_PickupTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[PickupTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_DropoffTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[DropoffTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_ZTS_Time
SELECT COUNT_BIG(*) FROM dbo.[Fact_Zone_Traffic_Snapshot] f LEFT JOIN dbo.[Dim_Time] d ON f.[TimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [TimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Zone_Traffic_Snapshot];
-- FK_FYG_PickupTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[PickupTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_DropoffTime
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Time] d ON f.[DropoffTimeKey]=d.[TimeKey] WHERE d.[TimeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffTimeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FHV_PickupLocation
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Location] d ON f.[PickupLocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupLocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_FHV_DropoffLocation
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Location] d ON f.[DropoffLocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffLocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_PickupLocation
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Location] d ON f.[PickupLocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupLocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_DropoffLocation
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Location] d ON f.[DropoffLocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffLocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_ZTS_Location
SELECT COUNT_BIG(*) FROM dbo.[Fact_Zone_Traffic_Snapshot] f LEFT JOIN dbo.[Dim_Location] d ON f.[LocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [LocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Zone_Traffic_Snapshot];
-- FK_FYG_PickupLocation
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Location] d ON f.[PickupLocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PickupLocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_DropoffLocation
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Location] d ON f.[DropoffLocationKey]=d.[LocationKey] WHERE d.[LocationKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DropoffLocationKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FHV_ServiceType
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_ServiceType] d ON f.[ServiceTypeKey]=d.[ServiceTypeKey] WHERE d.[ServiceTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [ServiceTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_ServiceType
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_ServiceType] d ON f.[ServiceTypeKey]=d.[ServiceTypeKey] WHERE d.[ServiceTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [ServiceTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_DFS_Service
SELECT COUNT_BIG(*) FROM dbo.[Fact_Daily_Financial_Snapshot] f LEFT JOIN dbo.[Dim_ServiceType] d ON f.[ServiceTypeKey]=d.[ServiceTypeKey] WHERE d.[ServiceTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [ServiceTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Daily_Financial_Snapshot];
-- FK_ZTS_Service
SELECT COUNT_BIG(*) FROM dbo.[Fact_Zone_Traffic_Snapshot] f LEFT JOIN dbo.[Dim_ServiceType] d ON f.[ServiceTypeKey]=d.[ServiceTypeKey] WHERE d.[ServiceTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [ServiceTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Zone_Traffic_Snapshot];
-- FK_BPS_Service
SELECT COUNT_BIG(*) FROM dbo.[Fact_Base_Performance_Snapshot] f LEFT JOIN dbo.[Dim_ServiceType] d ON f.[ServiceTypeKey]=d.[ServiceTypeKey] WHERE d.[ServiceTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [ServiceTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Base_Performance_Snapshot];
-- FK_FYG_ServiceType
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_ServiceType] d ON f.[ServiceTypeKey]=d.[ServiceTypeKey] WHERE d.[ServiceTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [ServiceTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_Vendor
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_Vendor] d ON f.[VendorKey]=d.[VendorKey] WHERE d.[VendorKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [VendorKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_HVFHV_Provider
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_HVFHSProvider] d ON f.[HVFHSProviderKey]=d.[HVFHSProviderKey] WHERE d.[HVFHSProviderKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [HVFHSProviderKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_BPS_Provider
SELECT COUNT_BIG(*) FROM dbo.[Fact_Base_Performance_Snapshot] f LEFT JOIN dbo.[Dim_HVFHSProvider] d ON f.[HVFHSProviderKey]=d.[HVFHSProviderKey] WHERE d.[HVFHSProviderKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [HVFHSProviderKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Base_Performance_Snapshot];
-- FK_FHV_DispatchBase
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Base] d ON f.[DispatchBaseKey]=d.[BaseKey] WHERE d.[BaseKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DispatchBaseKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_FHV_AffiliatedBase
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_Base] d ON f.[AffiliatedBaseKey]=d.[BaseKey] WHERE d.[BaseKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [AffiliatedBaseKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_DispatchBase
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Base] d ON f.[DispatchBaseKey]=d.[BaseKey] WHERE d.[BaseKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DispatchBaseKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_HVFHV_OriginBase
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_Base] d ON f.[OriginBaseKey]=d.[BaseKey] WHERE d.[BaseKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [OriginBaseKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_BPS_Base
SELECT COUNT_BIG(*) FROM dbo.[Fact_Base_Performance_Snapshot] f LEFT JOIN dbo.[Dim_Base] d ON f.[DispatchBaseKey]=d.[BaseKey] WHERE d.[BaseKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [DispatchBaseKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_Base_Performance_Snapshot];
-- FK_FYG_RateCode
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_RateCode] d ON f.[RateCodeKey]=d.[RateCodeKey] WHERE d.[RateCodeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [RateCodeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_PaymentType
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_PaymentType] d ON f.[PaymentTypeKey]=d.[PaymentTypeKey] WHERE d.[PaymentTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PaymentTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_TripType
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_TripType] d ON f.[TripTypeKey]=d.[TripTypeKey] WHERE d.[TripTypeKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [TripTypeKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FYG_TaxiFlag
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_TaxiFlags] d ON f.[TaxiFlagKey]=d.[TaxiFlagKey] WHERE d.[TaxiFlagKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [TaxiFlagKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FHV_Flag
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_FHVFlags] d ON f.[FHVFlagKey]=d.[FHVFlagKey] WHERE d.[FHVFlagKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [FHVFlagKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_Flag
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_HVFHVFlags] d ON f.[HVFHVFlagKey]=d.[HVFHVFlagKey] WHERE d.[HVFHVFlagKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [HVFHVFlagKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_FYG_PassengerGroup
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_PassengerGroup] d ON f.[PassengerGroupKey]=d.[PassengerGroupKey] WHERE d.[PassengerGroupKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [PassengerGroupKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
-- FK_FHV_LoadBatch
SELECT COUNT_BIG(*) FROM dbo.[Fact_FHV_Trips] f LEFT JOIN dbo.[Dim_LoadBatch] d ON f.[LoadBatchKey]=d.[LoadBatchKey] WHERE d.[LoadBatchKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [LoadBatchKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_FHV_Trips];
-- FK_HVFHV_LoadBatch
SELECT COUNT_BIG(*) FROM dbo.[Fact_HVFHV_Trips] f LEFT JOIN dbo.[Dim_LoadBatch] d ON f.[LoadBatchKey]=d.[LoadBatchKey] WHERE d.[LoadBatchKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [LoadBatchKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_HVFHV_Trips];
-- FK_FYG_LoadBatch
SELECT COUNT_BIG(*) FROM dbo.[Fact_YellowGreen_Trips] f LEFT JOIN dbo.[Dim_LoadBatch] d ON f.[LoadBatchKey]=d.[LoadBatchKey] WHERE d.[LoadBatchKey] IS NULL;
SELECT COUNT_BIG(*) AS FactRows, SUM(CAST(CASE WHEN [LoadBatchKey]=0 THEN 1 ELSE 0 END AS bigint)) AS UnknownRows FROM dbo.[Fact_YellowGreen_Trips];
