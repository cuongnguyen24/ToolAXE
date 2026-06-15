/*
    Post-install template for SQL Server 2022 Developer default instance.
    Adjust values for each customer before execution.
*/

SET NOCOUNT ON;

PRINT 'Post-install validation started';
SELECT @@VERSION AS sql_version;
SELECT SERVERPROPERTY('ServerName') AS server_name,
       SERVERPROPERTY('InstanceName') AS instance_name,
       SERVERPROPERTY('Edition') AS edition,
       SERVERPROPERTY('ProductVersion') AS product_version;

EXEC sys.sp_configure N'show advanced options', 1;
RECONFIGURE;

EXEC sys.sp_configure N'max server memory (MB)', 4096;
RECONFIGURE;

EXEC sys.sp_configure N'max degree of parallelism', 4;
RECONFIGURE;

EXEC sys.sp_configure N'cost threshold for parallelism', 50;
RECONFIGURE;

PRINT 'Post-install validation completed';
