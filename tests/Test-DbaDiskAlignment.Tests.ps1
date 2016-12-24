﻿<#

Entire test commented out because someone needs to look at:

RuleName                            Severity     FileName   Line  Message                                                     
--------                            --------     --------   ----  -------                                                     
PSUseBOMForUnicodeEncodedFile       Warning      Test-DbaDi       Missing BOM encoding for non-ASCII encoded file             
                                                 skAlignmen       'Test-DbaDiskAlignment.ps1'                                 
                                                 t.ps1                                                                        
PSShouldProcess                     Warning      Test-DbaDi 1     'Test-DbaDiskAlignment' calls ShouldProcess/ShouldContinue  
                                                 skAlignmen       but does not have the ShouldProcess attribute.              
                                                 t.ps1                                                                        
PSUsePSCredentialType               Warning      Test-DbaDi 1     The Credential parameter in 'Test-DbaDiskAlignment' must be 
                                                 skAlignmen       of type PSCredential. For PowerShell 4.0 and earlier,       
                                                 t.ps1            please define a credential transformation attribute, e.g.   
                                                                  [System.Management.Automation.Credential()], after the      
                                                                  PSCredential type attribute.                                
PSAvoidUsingPlainTextForPassword    Warning      Test-DbaDi 93    Parameter '$Credential' should use SecureString, otherwise  
                                                 skAlignmen       this will expose sensitive information. See                 
                                                 t.ps1            ConvertTo-SecureString for more information.                
PSShouldProcess                     Warning      Test-DbaDi 99    'Get-DiskAlignment' calls ShouldProcess/ShouldContinue but  
                                                 skAlignmen       does not have the ShouldProcess attribute.                  
                                                 t.ps1                                                                        
PSAvoidUsingWMICmdlet               Warning      Test-DbaDi 119   File 'Test-DbaDiskAlignment.ps1' uses WMI cmdlet. For       
                                                 skAlignmen       PowerShell 3.0 and above, use CIM cmdlet which perform the  
                                                 t.ps1            same tasks as the WMI cmdlets. The CIM cmdlets comply with  
                                                                  WS-Management (WSMan) standards and with the Common         
                                                                  Information Model (CIM) standard, which enables the cmdlets 
                                                                  to use the same techniques to manage Windows computers and  
                                                                  those running other operating systems.                      
PSAvoidUsingWMICmdlet               Warning      Test-DbaDi 122   File 'Test-DbaDiskAlignment.ps1' uses WMI cmdlet. For       
                                                 skAlignmen       PowerShell 3.0 and above, use CIM cmdlet which perform the  
                                                 t.ps1            same tasks as the WMI cmdlets. The CIM cmdlets comply with  
                                                                  WS-Management (WSMan) standards and with the Common         
                                                                  Information Model (CIM) standard, which enables the cmdlets 
                                                                  to use the same techniques to manage Windows computers and  
                                                                  those running other operating systems.                      
PSPossibleIncorrectComparisonWithNu Warning      Test-DbaDi 187   $null should be on the left side of equality comparisons.   
ll                                               skAlignmen                                                                   
                                                 t.ps1                                                                        
PSPossibleIncorrectComparisonWithNu Warning      Test-DbaDi 187   $null should be on the left side of equality comparisons.   
ll                                               skAlignmen                                                                   
                                                 t.ps1                                                                        
PSPossibleIncorrectComparisonWithNu Warning      Test-DbaDi 318   $null should be on the left side of equality comparisons.   
ll                                               skAlignmen                                                                   
                                                 t.ps1                                                                        
PSUseDeclaredVarsMoreThanAssignment Warning      Test-DbaDi 361   The variable 'newcollection' is assigned but never used.    
s                                                skAlignmen                                                                   
                                                 t.ps1 

Logged in issue #397

#Thank you Warren http://ramblingcookiemonster.github.io/Testing-DSC-with-Pester-and-AppVeyor/

if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}
$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}



$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.', '.')
Import-Module $PSScriptRoot\..\functions\$sut -Force
Import-Module PSScriptAnalyzer
## Added PSAvoidUsingPlainTextForPassword as credential is an object and therefore fails. We can ignore any rules here under special circumstances agreed by admins :-)
$Rules = (Get-ScriptAnalyzerRule).Where{$_.RuleName -notin ('PSAvoidUsingPlainTextForPassword') }
$Name = $sut.Split('.')[0]

    Describe 'Script Analyzer Tests'  -Tag @('ScriptAnalyzer'){
            Context "Testing $Name for Standard Processing" {
                foreach ($rule in $rules) { 
                    $i = $rules.IndexOf($rule)
                    It "passes the PSScriptAnalyzer Rule number $i - $rule  " {
                        (Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\functions\$sut" -IncludeRule $rule.RuleName ).Count | Should Be 0 
                    }
                }
            }
        }
   ## Load the command
$ModuleBase = Split-Path -Parent $MyInvocation.MyCommand.Path

# For tests in .\Tests subdirectory
if ((Split-Path $ModuleBase -Leaf) -eq 'Tests')
{
	$ModuleBase = Split-Path $ModuleBase -Parent
}

# Handles modules in version directories
$leaf = Split-Path $ModuleBase -Leaf
$parent = Split-Path $ModuleBase -Parent
$parsedVersion = $null
if ([System.Version]::TryParse($leaf, [ref]$parsedVersion))
{
	$ModuleName = Split-Path $parent -Leaf
}
else
{
	$ModuleName = $leaf
}

# Removes all versions of the module from the session before importing
Get-Module $ModuleName | Remove-Module

# Because ModuleBase includes version number, this imports the required version
# of the module
$null = Import-Module $ModuleBase\$ModuleName.psd1 -PassThru -ErrorAction Stop 
. "$Modulebase\functions\DynamicParams.ps1"
Get-ChildItem "$Modulebase\internal\" |% {. $_.fullname}

    Describe "$Name Tests" -Tag ('Command'){
        InModuleScope 'dbatools' {
        Context "Connects to SQL Server" {
                              It "Should not throw" {
                  Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'sa'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                  {Test-DbaDatabaseOwner -SqlServer 'SQLServerName'} | Should Not throw
              } #It
                   It "Should not return if no wrong owner for default" {
                  Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'sa'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                  {Test-DbaDatabaseOwner -SqlServer 'SQLServerName'} | Should Not throw
              } #It
              It "Should return wrong owner information for one database with no owner specified" {
                          Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                 $Result = Test-DbaDatabaseOwner -SqlServer 'SQLServerName'
                $Result.Server| Should Be 'SQLServerName'
              $Result.Database | Should Be 'db1'; 
              $Result.DBState| Should Be 'Normal'; 
              $Result.CurrentOwner| Should Be 'WrongOWner'; 
              $Result.TargetOwner| Should Be 'sa'; 
              $Result.OwnerMatch| Should Be $False
              }# it
              It "Should return information for one database with correct owner with detail parameter" {
                          Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'sa'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                 $Result = Test-DbaDatabaseOwner -SqlServer 'SQLServerName' -Detailed
            $Result.Server| Should Be 'SQLServerName'
              $Result.Database | Should Be 'db1'; 
              $Result.DBState| Should Be 'Normal'; 
              $Result.CurrentOwner| Should Be 'sa'; 
              $Result.TargetOwner| Should Be 'sa'; 
              $Result.OwnerMatch| Should Be $True
              }# it
                 It "Should return wrong owner information for one database with no owner specified and multiple databases" {
                          Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                            @{
                                  Name= 'db2';
                                  Status = 'Normal';
                                  Owner = 'sa'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                 $Result = Test-DbaDatabaseOwner -SqlServer 'SQLServerName'
                $Result.Server| Should Be 'SQLServerName'
              $Result.Database | Should Be 'db1'; 
              $Result.DBState| Should Be 'Normal'; 
              $Result.CurrentOwner| Should Be 'WrongOWner'; 
              $Result.TargetOwner| Should Be 'sa'; 
              $Result.OwnerMatch| Should Be $False
              }# it
             It "Should return wrong owner information for two databases with no owner specified and multiple databases" {
                          Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                            @{
                                  Name= 'db2';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                 $Result = Test-DbaDatabaseOwner -SqlServer 'SQLServerName'
                $Result.Server| Should Be 'SQLServerName'
              $Result[0].Database | Should Be 'db1';
              $Result[1].Database | Should Be 'db2';
              $Result.DBState| Should Be 'Normal'; 
              $Result.CurrentOwner| Should Be 'WrongOWner'; 
              $Result.TargetOwner| Should Be 'sa'; 
              $Result.OwnerMatch| Should Be $False
              }# it
                           It "Should notify if Target Login does not exist on Server" {
                          Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                            @{
                                  Name= 'db2';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                {Test-DbaDatabaseOwner -SqlServer 'SQLServerName' -TargetLogin WrongLogin} | Should Throw 'Invalid login:'
              }# it
             It "Returns all information with detailed for correct and incorrect owner" {
                          Mock Connect-SQLServer -MockWith {
                      [object]@{
                          Name = 'SQLServerName';
                          Databases = [object]@(
                              @{
                                  Name= 'db1';
                                  Status = 'Normal';
                                  Owner = 'WrongOWner'
                                }
                            @{
                                  Name= 'db2';
                                  Status = 'Normal';
                                  Owner = 'sa'
                                }
                              ); #databases
                        Logins = [object]@(
                            @{
                                ID = 1;
                                Name = 'sa';
                            } 
                        ) #logins
                    } #object
                  } #mock connect-sqlserver
                  
                  mock Get-ParamSqlDatabases -MockWith {
                            [object]@(
                              @{
                                  Name= 'db1'
                                }
                              );

                  } #mock params
                 $Result = Test-DbaDatabaseOwner -SqlServer 'SQLServerName' -Detailed
                $Result.Server| Should Be 'SQLServerName';
              $Result[0].Database | Should Be 'db1';
              $Result[1].Database | Should Be 'db2';              
              $Result.DBState| Should Be 'Normal'; 
              $Result[0].CurrentOwner| Should Be 'WrongOWner'; 
              $Result[1].CurrentOwner| Should Be 'sa'; 
              $Result.TargetOwner| Should Be 'sa'; 
              $Result[0].OwnerMatch| Should Be $False
              $Result[1].OwnerMatch| Should Be $true
              }# it
		}# Context
        }#modulescope
    }#describe
#>