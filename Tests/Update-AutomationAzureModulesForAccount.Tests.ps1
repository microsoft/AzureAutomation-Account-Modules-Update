<#
Copyright (c) Microsoft Corporation. All rights reserved.
Licensed under the MIT License.
#>

#requires -Modules @{ ModuleName='Pester'; ModuleVersion='4.1.1' }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sutDirectory = Split-Path -Parent $here
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

Describe 'Update-AutomationAzureModulesForAccount runbook' {

    #region Stub external commands

    function Import-Module {
        [CmdletBinding()]
        param($Name, [switch]$Force)
    }

    function New-Object($TypeName) { }

    function Start-Sleep($Seconds) { }

    function Invoke-RestMethod($Method, $Uri, [switch]$UseBasicParsing) { }

    function Invoke-WebRequest($Uri, $MaximumRedirection, [switch]$UseBasicParsing, $ErrorAction) {}

    function Expand-Archive($Path, $DestinationPath, [switch]$Force) { }

    function Get-AzureRmAutomationModule($Name, $ResourceGroupName, $AutomationAccountName) { }

    function New-AzureRmAutomationModule($ResourceGroupName, $AutomationAccountName, $Name, $ContentLink) { }

    function Get-AzAutomationModule($Name, $ResourceGroupName, $AutomationAccountName) { }

    function New-AzAutomationModule($ResourceGroupName, $AutomationAccountName, $Name, $ContentLink) { }

    #endregion

    #region Global mocks

    Mock New-Object {
        $TypeName | Should be 'System.Net.WebClient'
        [FakeWebClient]::New()
    }

    #endregion

    #region Test utilities

    function Invoke-Update-AutomationAzureModulesForAccount($OptionalParameters) {
        $script:LastErrors = $null
    
        if ($null -eq $OptionalParameters) {
            $OptionalParameters = @{ }
        }

        & "$sutDirectory\$sut" `
            -ResourceGroupName 'Fake RG' `
            -AutomationAccountName 'Fake account' `
            -Login $false `
            -ManagedIdentity $false `
            -ErrorAction SilentlyContinue `
            -ErrorVariable script:LastErrors `
            @OptionalParameters
    
        It 'Reports no errors' { $script:LastErrors | Should be $null }
    }

    class FakeWebClient {
        [void]DownloadFile($SourceUrl, $DestinationPath) { }
    }

    function Assert-CorrectSearchUri($Uri, $ModuleName, $Filter = 'IsLatestVersion') {
        $ExpectedUri = "https://www.powershellgallery.com/api/v2/Search()?`$filter=$Filter&searchTerm=%27$ModuleName%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40"
        $Uri | Should be $ExpectedUri > $null
    }

    #endregion
    
    Context 'No overridden module versions' {
        Mock Get-AzureRmAutomationModule {
            @{
                Name = 'AzureRM.FakeAzureModule'
                Version = '1.0.0'
                ProvisioningState = 'Succeeded'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM\.Automation%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.Automation
            
            @{
                id = 'fake AzureRM.Automation search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Automation search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'AzureRM.Profile:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM\.Profile%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.Profile
            
            @{
                id = 'fake AzureRM.Profile search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Profile search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -eq 'https://www.powershellgallery.com/api/v2/package/AzureRM.Profile'
        } -MockWith {
            @{
                Headers = @{
                    Location = 'Fake/AzureRM.Profile/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzureRmAutomationModule -ParameterFilter {
            $Name -eq 'AzureRM.Profile'
        } -MockWith {
            $ContentLink | Should be 'Fake/AzureRM.Profile/Content/Location.nupkg' > $null
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM.FakeAzureModule%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.FakeAzureModule
            
            @{
                id = 'fake FakeAzureModule search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake FakeAzureModule search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'AzureRM.Profile:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -match 'https://www.powershellgallery.com/api/v2/package/AzureRM.FakeAzureModule'
        } -MockWith {
            $Uri | Should be 'https://www.powershellgallery.com/api/v2/package/AzureRM.FakeAzureModule' > $null

            @{
                Headers = @{
                    Location = 'Fake/AzureRM.FakeAzureModule/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzureRmAutomationModule -ParameterFilter {
            $Name -eq 'AzureRM.FakeAzureModule'
        } -MockWith {
            $ContentLink | Should be 'Fake/AzureRM.FakeAzureModule/Content/Location.nupkg' > $null
        } -Verifiable

        Invoke-Update-AutomationAzureModulesForAccount -OptionalParameters @{
            ModuleVersionOverrides = '{ }'
        }

        It 'Updates AzureRM.Profile module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'AzureRM.Profile' } -Times 1 -Exactly
        }

        It 'Updates fake Azure module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'AzureRM.FakeAzureModule' } -Times 1 -Exactly
        }

        Assert-VerifiableMock
    }
    
    Context 'With overridden module versions' {
        Mock Get-AzureRmAutomationModule {
            @{
                Name = 'AzureRM.FakeAzureModule'
                Version = '1.0.0'
                ProvisioningState = 'Succeeded'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM\.Automation%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.Automation
            
            @{
                id = 'fake AzureRM.Automation search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Automation search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'AzureRM.Profile:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM\.Profile%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.Profile -Filter "Version%20eq%20'2.0.0'"
            
            @{
                id = 'fake AzureRM.Profile search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Profile search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -match 'AzureRM\.Profile'
        } -MockWith {
            $Uri | Should be 'https://www.powershellgallery.com/api/v2/package/AzureRM.Profile/2.0.0' > $null

            @{
                Headers = @{
                    Location = 'Fake/AzureRM.Profile/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzureRmAutomationModule -ParameterFilter {
            $Name -eq 'AzureRM.Profile'
        } -MockWith {
            $ContentLink | Should be 'Fake/AzureRM.Profile/Content/Location.nupkg' > $null
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM.FakeAzureModule%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.FakeAzureModule
            
            @{
                id = 'fake FakeAzureModule search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake FakeAzureModule search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'AzureRM.Profile:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -match 'https://www.powershellgallery.com/api/v2/package/AzureRM.FakeAzureModule'
        } -MockWith {
            $Uri | Should be 'https://www.powershellgallery.com/api/v2/package/AzureRM.FakeAzureModule' > $null

            @{
                Headers = @{
                    Location = 'Fake/AzureRM.FakeAzureModule/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzureRmAutomationModule -ParameterFilter {
            $Name -eq 'AzureRM.FakeAzureModule'
        } -MockWith {
            $ContentLink | Should be 'Fake/AzureRM.FakeAzureModule/Content/Location.nupkg' > $null
        } -Verifiable

        Invoke-Update-AutomationAzureModulesForAccount -OptionalParameters @{
            ModuleVersionOverrides = "{
                'AzureRM.Profile' : '2.0.0'
            }"
        }

        It 'Updates AzureRM.Profile module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'AzureRM.Profile' } -Times 1 -Exactly
        }

        It 'Updates fake Azure module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'AzureRM.FakeAzureModule' } -Times 1 -Exactly
        }

        Assert-VerifiableMock
    }
    
    Context 'When found multiple modules with similar name' {
        #region Expect these calls, but don't assert anything, as they are not relevant to this specific test

        Mock Invoke-RestMethod -ParameterFilter { $Uri -match '%27AzureRM\.Automation%27' } `
            -MockWith { @{ id = 'fake AzureRM.Automation search result id' } }

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Automation search result id'
        } -MockWith {
            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'AzureRM.Profile:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        }

        Mock Invoke-RestMethod -ParameterFilter { $Uri -match '%27AzureRM\.Profile%27' } `
            -MockWith { @{ id = 'fake AzureRM.Profile search result id' } }

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Profile search result id'
        } -MockWith {
            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        }

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -match 'AzureRM\.Profile'
        } -MockWith {
            @{
                Headers = @{
                    Location = 'Fake/AzureRM.Profile/Content/Location.nupkg'
                }
            }
        }

        #endregion

        Mock Get-AzureRmAutomationModule {
            @{
                Name = 'AzureRM.FakeAzureModule'
                Version = '1.0.0'
                ProvisioningState = 'Succeeded'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM.FakeAzureModule%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.FakeAzureModule -Filter "Version%20eq%20'2.0.0'"
            
            @{
                id = 'fake FakeAzureModule search result id 1'
                title = @{ InnerText = 'AzureRM.FakeAzureModule.Different' }
            }
            
            @{
                id = 'fake FakeAzureModule search result id 2'
                title = @{ InnerText = 'AzureRM.FakeAzureModule' }
            }
            
            @{
                id = 'fake FakeAzureModule search result id 3'
                title = @{ InnerText = 'AzureRM.FakeAzureModule.AnotherOne' }
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake FakeAzureModule search result id 2'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = '2.0.0'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -match 'https://www.powershellgallery.com/api/v2/package/AzureRM.FakeAzureModule'
        } -MockWith {
            $Uri | Should be 'https://www.powershellgallery.com/api/v2/package/AzureRM.FakeAzureModule/2.0.0' > $null

            @{
                Headers = @{
                    Location = 'Fake/AzureRM.FakeAzureModule/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzureRmAutomationModule -ParameterFilter {
            $Name -eq 'AzureRM.FakeAzureModule'
        } -MockWith {
            $ContentLink | Should be 'Fake/AzureRM.FakeAzureModule/Content/Location.nupkg' > $null
        } -Verifiable

        Invoke-Update-AutomationAzureModulesForAccount -OptionalParameters @{
            ModuleVersionOverrides = "{
                'AzureRM.FakeAzureModule' : '2.0.0'
            }"
        }

        It 'Updates fake Azure module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'AzureRM.FakeAzureModule' } -Times 1 -Exactly
        }

        Assert-VerifiableMock
    }

    Context 'Az module present with default ModuleClassName AzureRM' {
        Mock Get-AzureRmAutomationModule {
            @{
                Name = 'Az.FakeAzModule'
                Version = '1.0.0'
                ProvisioningState = 'Succeeded'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM\.Automation%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.Automation

            @{
                id = 'fake AzureRM.Automation search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Automation search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'AzureRM.Profile:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27AzureRM\.Profile%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName AzureRM.Profile

            @{
                id = 'fake AzureRM.Profile search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake AzureRM.Profile search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -eq 'https://www.powershellgallery.com/api/v2/package/AzureRM.Profile'
        } -MockWith {
            @{
                Headers = @{
                    Location = 'Fake/AzureRM.Profile/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzureRmAutomationModule -ParameterFilter {
            $Name -eq 'AzureRM.Profile'
        } -MockWith {
            $ContentLink | Should be 'Fake/AzureRM.Profile/Content/Location.nupkg' > $null
        } -Verifiable

        Invoke-Update-AutomationAzureModulesForAccount -OptionalParameters @{
            ModuleVersionOverrides = '{ }'
        }

        It 'Updates AzureRM.Profile module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'AzureRM.Profile' } -Times 1 -Exactly
        }

        It 'Ignores fake Az module' {
            Assert-MockCalled New-AzureRmAutomationModule -ParameterFilter { $Name -eq 'Az.FakeAzModule' } -Times 0 -Exactly
        }

        Assert-VerifiableMock
    }

    Context 'AzureRM module present with ModuleClassName Az' {
        Mock Get-AzAutomationModule {
            @{
                Name = 'AzureRM.FakeAzureModule'
                Version = '1.0.0'
                ProvisioningState = 'Succeeded'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27Az\.Automation%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName Az.Automation

            @{
                id = 'fake Az.Automation search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake Az.Automation search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'Az.Accounts:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27Az\.Accounts%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName Az.Accounts

            @{
                id = 'fake Az.Accounts search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake Az.Accounts search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -eq 'https://www.powershellgallery.com/api/v2/package/Az.Accounts'
        } -MockWith {
            @{
                Headers = @{
                    Location = 'Fake/Az.Accounts/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzAutomationModule -ParameterFilter {
            $Name -eq 'Az.Accounts'
        } -MockWith {
            $ContentLink | Should be 'Fake/Az.Accounts/Content/Location.nupkg' > $null
        } -Verifiable

        Invoke-Update-AutomationAzureModulesForAccount -OptionalParameters @{
            ModuleVersionOverrides = '{ }'
            AzureModuleClass = 'Az'
        }

        It 'Updates Az.Accounts module' {
            Assert-MockCalled New-AzAutomationModule -ParameterFilter { $Name -eq 'Az.Accounts' } -Times 1 -Exactly
        }

        It 'Ignores fake AzureRM module' {
            Assert-MockCalled New-AzAutomationModule -ParameterFilter { $Name -eq 'AzureRM.FakeAzureModule' } -Times 0 -Exactly
        }

        Assert-VerifiableMock
    }

    Context 'Az module present with ModuleClassName Az' {
        Mock Get-AzAutomationModule {
            @{
                Name = 'Az.FakeAzModule'
                Version = '1.0.0'
                ProvisioningState = 'Succeeded'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27Az\.Automation%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName Az.Automation

            @{
                id = 'fake Az.Automation search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake Az.Automation search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'Az.Accounts:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27Az\.Accounts%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName Az.Accounts

            @{
                id = 'fake Az.Accounts search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake Az.Accounts search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = ''
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -eq 'https://www.powershellgallery.com/api/v2/package/Az.Accounts'
        } -MockWith {
            @{
                Headers = @{
                    Location = 'Fake/Az.Accounts/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzAutomationModule -ParameterFilter {
            $Name -eq 'Az.Accounts'
        } -MockWith {
            $ContentLink | Should be 'Fake/Az.Accounts/Content/Location.nupkg' > $null
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -match '%27Az.FakeAzModule%27'
        } -MockWith {
            $Method | Should be 'Get' > $null
            Assert-CorrectSearchUri -Uri $Uri -ModuleName Az.FakeAzModule

            @{
                id = 'fake FakeAzModule search result id'
            }
        } -Verifiable

        Mock Invoke-RestMethod -ParameterFilter {
            $Uri -eq 'fake FakeAzModule search result id'
        } -MockWith {
            $Method | Should be 'Get' > $null

            @{
                entry = @{
                    properties = @{
                        version = 'fake version'
                        dependencies = 'Az.Accounts:[1.0.0]:'
                        owners = 'azure-sdk'
                    }
                }
            }
        } -Verifiable

        Mock Invoke-WebRequest -ParameterFilter {
            $Uri -match 'https://www.powershellgallery.com/api/v2/package/Az.FakeAzModule'
        } -MockWith {
            $Uri | Should be 'https://www.powershellgallery.com/api/v2/package/Az.FakeAzModule' > $null

            @{
                Headers = @{
                    Location = 'Fake/Az.FakeAzModule/Content/Location.nupkg'
                }
            }
        } -Verifiable

        Mock New-AzAutomationModule -ParameterFilter {
            $Name -eq 'Az.FakeAzModule'
        } -MockWith {
            $ContentLink | Should be 'Fake/Az.FakeAzModule/Content/Location.nupkg' > $null
        } -Verifiable

        Invoke-Update-AutomationAzureModulesForAccount -OptionalParameters @{
            ModuleVersionOverrides = '{ }'
            AzureModuleClass = 'Az'
        }

        It 'Updates Az.Accounts module' {
            Assert-MockCalled New-AzAutomationModule -ParameterFilter { $Name -eq 'Az.Accounts' } -Times 1 -Exactly
        }

        It 'Updates fake Az module' {
            Assert-MockCalled New-AzAutomationModule -ParameterFilter { $Name -eq 'Az.FakeAzModule' } -Times 1 -Exactly
        }

        Assert-VerifiableMock
    }

}
