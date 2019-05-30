Install-Module -Name Pester -MinimumVersion 4.8.1 -Force -SkipPublisherCheck

Invoke-Pester -Script "./Tests/" -OutputFile "./Test-Pester.XML" -OutputFormat 'NUnitXML' `
    -CodeCoverage "./Update-AutomationAzureModulesForAccount.ps1"