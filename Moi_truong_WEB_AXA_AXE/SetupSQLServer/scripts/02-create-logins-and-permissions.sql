/*
    Sample security script.
    Replace login names, passwords, database names, and permissions as needed.
*/

SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'axe_app_user')
BEGIN
    CREATE LOGIN [axe_app_user]
    WITH PASSWORD = N'ChangeThisAppPassword!',
         CHECK_POLICY = ON,
         CHECK_EXPIRATION = OFF,
         DEFAULT_DATABASE = [master];
    PRINT 'Created SQL login [axe_app_user]';
END
ELSE
BEGIN
    PRINT 'Login [axe_app_user] already exists';
END

IF DB_ID(N'AXE_APP') IS NOT NULL
BEGIN
    USE [AXE_APP];

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'axe_app_user')
    BEGIN
        CREATE USER [axe_app_user] FOR LOGIN [axe_app_user];
        PRINT 'Created database user [axe_app_user] in [AXE_APP]';
    END

    ALTER ROLE [db_datareader] ADD MEMBER [axe_app_user];
    ALTER ROLE [db_datawriter] ADD MEMBER [axe_app_user];
    PRINT 'Granted db_datareader and db_datawriter to [axe_app_user]';
END
ELSE
BEGIN
    PRINT 'Database [AXE_APP] does not exist. Skip user and permission creation.';
END
