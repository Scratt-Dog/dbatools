<#

Commented out someone needs to look at 





RuleName                            Severity     FileName   Line  Message                                                     
--------                            --------     --------   ----  -------                                                     
PSUseShouldProcessForStateChangingF Warning      Copy-SqlSs 191   Function ?New-CatalogFolder? has verb that could change     
unctions                                         isCatalog.       system state. Therefore, the function has to support        
                                                 ps1              'ShouldProcess'.                                            
PSUseShouldProcessForStateChangingF Warning      Copy-SqlSs 222   Function ?New-FolderEnvironment? has verb that could change 
unctions                                         isCatalog.       system state. Therefore, the function has to support        
                                                 ps1              'ShouldProcess'.                                            
PSUseShouldProcessForStateChangingF Warning      Copy-SqlSs 256   Function ?New-SSISDBCatalog? has verb that could change     
unctions                                         isCatalog.       system state. Therefore, the function has to support        
                                                 ps1              'ShouldProcess'.                                            
PSPossibleIncorrectComparisonWithNu Warning      Copy-SqlSs 163   $null should be on the left side of equality comparisons.   
ll                                               isCatalog.                                                                   
                                                 ps1                                                                          
PSPossibleIncorrectComparisonWithNu Warning      Copy-SqlSs 163   $null should be on the left side of equality comparisons.   
ll                                               isCatalog.                                                                   
                                                 ps1                                                                          
PSAvoidUsingEmptyCatchBlock         Warning      Copy-SqlSs 504   Empty catch block is used. Please use Write-Error or throw  
                                                 isCatalog.       statements in catch blocks.                                 
                                                 ps1                                                                          
PSUseBOMForUnicodeEncodedFile       Warning      Copy-SqlSs       Missing BOM encoding for non-ASCII encoded file             
                                                 isCatalog.       'Copy-SqlSsisCatalog.ps1'                                   
                                                 ps1                                                                          




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
## Added PSAvoidUsingPlainTextForPassword as credential is an object and therefore fails. 
## We can ignore any rules here under special circumstances agreed by admins :-)
## We expect some context using comments about the reason for ignoring a rule

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
            Context " There should be some functional tests here" {
                It "Does a thing" {
                    $ActualValue | Should Be $ExpectedValue
                }
		    }# Context
        }#modulescope
    }#describe
    #>
    