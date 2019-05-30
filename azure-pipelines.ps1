if (-not (Get-Module -Name Pester -ListAvailable)) {
    Install-Module -Name Pester -Force -SkipPublisherCheck
}

Invoke-Pester -Script "./Tests/" -OutputFile "./Test-Pester.XML" -OutputFormat 'NUnitXML' `
    -CodeCoverage "./Update-AutomationAzureModulesForAccount.ps1"