﻿Function Export-SqlUser
{
<#
.SYNOPSIS
Exports Windows and SQL Users to a T-SQL file.

.DESCRIPTION
Exports Windows and SQL Users to a T-SQL file. Export includes user, create and add to role(s), database level permissions, object level permissions.

THIS CODE IS PROVIDED "AS IS", WITH NO WARRANTIES.

.PARAMETER SqlInstance
The SQL Server instance name. SQL Server 2000 and above supported.

.PARAMETER FilePath
The file to write to.

.PARAMETER NoClobber
Do not overwrite file
	
.PARAMETER Append
Append to file

.EXAMPLE
Export-SqlUser -SqlServer sql2005 -FilePath C:\temp\sql2005-users.sql

Exports SQL for the users in server "sql2005" and writes them to the file "C:\temp\sql2005-users.sql"

.EXAMPLE
Export-SqlUser -SqlServer sqlserver2014a $scred -FilePath C:\temp\users.sql -Append

Authenticates to sqlserver2014a using SQL Authentication. Exports all users to C:\temp\users.sql, and appends to the file if it exists. If not, the file will be created.

.EXAMPLE
Export-SqlUser -SqlServer sqlserver2014a -User User1, User2 -FilePath C:\temp\users.sql

Exports ONLY users User1 and User2 fron sqlsever2014a to the file  C:\temp\users.sql

.NOTES
Original Author: Cláudio Silva (@ClaudioESSilva)
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.


.LINK
https://dbatools.io/Export-SqlUser
#>
	[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[string]$SqlInstance,
        [object[]]$User,
		[Alias("OutFile", "Path","FileName")]
		[string]$FilePath,
		[object]$SqlCredential,
		[Alias("NoOverwrite")]
		[switch]$NoClobber,
		[switch]$Append
	)
	
	DynamicParam 
    { 
        if ($SqlInstance)
		{
            return Get-ParamSqlDatabases -SqlServer $SqlInstance -SqlCredential $SqlCredential
		}
    }
	BEGIN
	{
        if ($FilePath.Length -gt 0)
		{
			if ($FilePath -notlike "*\*") { $FilePath = ".\$filepath" }
			$directory = Split-Path $FilePath
			$exists = Test-Path $directory
			
			if ($exists -eq $false)
			{
				throw "Parent directory $directory does not exist"
			}
			
			Write-Output "--Attempting to connect to SQL Servers.."
		}

        $sourceserver = Connect-SqlServer -SqlServer $SqlInstance -SqlCredential $SqlCredential

		$outsql = @()
    }
	
	PROCESS
	{
        # Convert from RuntimeDefinedParameter object to regular array
		$databases = $psboundparameters.Databases
		$Exclude = $psboundparameters.Exclude

        if ($databases.Count -eq 0)
        {
            $databases = $sourceserver.Databases | Where-Object {$_.IsSystemObject -eq $false -and $_.IsAccessible -eq $true}
        }
        else
        {
            if ($pipedatabase.Length -gt 0)
		    {
			    $Source = $pipedatabase[0].parent.name
			    $databases = $pipedatabase.name
		    }
            else
            {
                $databases = $sourceserver.Databases | Where-Object {$_.IsSystemObject -eq $false -and $_.IsAccessible -eq $true -and ($databases -contains $_.Name)}
            }
        }

        if (@($databases).Count -gt 0)
        {

            #Database Permissions
            foreach ($db in $databases)
            {
                #Get compatibility level for scripting the objects
                $scriptVersion = $db.CompatibilityLevel

                #Options
                [Microsoft.SqlServer.Management.Smo.ScriptingOptions] $ScriptingOptions = New-Object "Microsoft.SqlServer.Management.Smo.ScriptingOptions";
                $ScriptingOptions.TargetServerVersion = [Microsoft.SqlServer.Management.Smo.SqlServerVersion]::$scriptVersion
                $ScriptingOptions.AllowSystemObjects = $false
                $ScriptingOptions.IncludeDatabaseRoleMemberships = $true
                $ScriptingOptions.ContinueScriptingOnError = $false;
                $ScriptingOptions.IncludeDatabaseContext = $false;

                Write-Output "Validating users on database '$($db.Name)'"

                if ($User.Count -eq 0)
                {
                    $Users = $db.Users | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -notlike "##*"}
                }
                else
                {
                    if ($pipedatabase.Length -gt 0)
		            {
			            $Source = $pipedatabase[3].parent.name
			            $Users = $pipedatabase.name
		            }
                    else
                    {
                        $Users = $db.Users | Where-Object {$User -contains $_.Name -and $_.IsSystemObject -eq $false -and $_.Name -notlike "##*"}
                    }
                }
                   
                if ($Users.Count -gt 0)
                { 
                    foreach ($dbuser in $Users)
                    {
                        #setting database
                        $outsql += "USE [" + $db.Name + "]"

	                    #Fixed Roles #Dependency Issue. Create Role, before add to role.
                        foreach ($RolePermission in ($db.Roles | Where-Object {$_.IsFixedRole -eq $false}))
                        { 
                            foreach ($RolePermissionScript in $RolePermission.Script($ScriptingOptions))
                            {
                                #$RoleScript = $RolePermission.Script($ScriptingOptions)
                                $outsql += "$($RolePermissionScript.ToString())"
                            }
                        }
	                 
                        #Database Create User(s) and add to Role(s)
                        foreach ($UserPermissionScript in $dbuser.Script($ScriptingOptions))
                        {
                            if ($dbuserPermissionScript.Contains("sp_addrolemember"))
                            {
                                $Execute = "EXEC "
                            } 
                            else 
                            {
                                $Execute = ""
                            }
                            $outsql += "$Execute$($UserPermissionScript.ToString())"
                        }

	                    #Database Permissions
                        foreach ($DatabasePermission in $db.EnumDatabasePermissions() | Where-Object {@("sa","dbo","information_schema","sys") -notcontains $_.Grantee -and $_.Grantee -notlike "##*" -and ($dbuser.Name -contains $_.Grantee)})
                        {
                            if ($DatabasePermission.PermissionState -eq "GrantWithGrant")
                            {
                                $WithGrant = "WITH GRANT OPTION"
                            } 
                            else 
                            {
                                $WithGrant = ""
                            }
                            $GrantDatabasePermission = $DatabasePermission.PermissionState.ToString().Replace("WithGrant", "").ToUpper()

                            $outsql += "$($GrantDatabasePermission) $($DatabasePermission.PermissionType) TO [$($DatabasePermission.Grantee)] $WithGrant"
                        }


	                    #Database Object Permissions
                        foreach ($ObjectPermission in $db.EnumObjectPermissions() | Where-Object {@("sa","dbo","information_schema","sys") -notcontains $_.Grantee -and $_.Grantee -notlike "##*" -and $dbuser.Name -contains $_.Grantee})
                        {
                            switch ($ObjectPermission.ObjectClass)
				            {
					            "Schema" 
                                { 
                                    $Object = "SCHEMA::[" + $ObjectPermission.ObjectName + "]" 
                                }
					    
                                "User" 
                                { 
                                    $Object = "USER::[" + $ObjectPermission.ObjectName + "]" 
                                }
                        
                                default 
                                { 
                                    $Object = "[" + $ObjectPermission.ObjectSchema + "].[" + $ObjectPermission.ObjectName + "]" 
                                }
				            }

                            if ($ObjectPermission.PermissionState -eq "GrantWithGrant")
                            {
                                $WithGrant = "WITH GRANT OPTION"
                        
                            } 
                            else 
                            {
                                $WithGrant = ""
                            }
                            $GrantObjectPermission = $ObjectPermission.PermissionState.ToString().Replace("WithGrant","").ToUpper()

                            $outsql += "$GrantObjectPermission $($ObjectPermission.PermissionType) ON $Object TO [$($ObjectPermission.Grantee)] $WithGrant"
                        }
                    }
                }
                else
                {
                    Write-Output "No users found on database '$db'"
                }
                
                #reset collection
                $Users = $null
            }
        }
        else
        {
            Write-Output "No users found on instance '$sourceserver'"
        }
    }
	END
	{
        $sql = $outsql -join "`r`nGO`r`n"
        #add the final GO
        $sql += "`r`nGO"
		
		if ($FilePath.Length -gt 0)
		{
			$sql | Out-File -FilePath $FilePath -Append:$Append -NoClobber:$NoClobber
		}
		else
		{
			return $sql
		}
		
		If ($Pscmdlet.ShouldProcess("console", "Showing final message"))
		{
			Write-Output "--SQL User export to $FilePath complete"
			$sourceserver.ConnectionContext.Disconnect()
		}
	}
}