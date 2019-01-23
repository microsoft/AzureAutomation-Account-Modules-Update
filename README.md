# Updating Azure PowerShell modules in Azure Automation accounts

## Purpose

This Azure Automation runbook updates Azure PowerShell modules imported into an Azure Automation
account with the module versions published to the PowerShell Gallery. See
[How to update Azure PowerShell modules in Azure Automation](https://docs.microsoft.com/en-us/azure/automation/automation-update-azure-modules)
for more details.

## Usage

Import this runbook into your Automation account, and [start](https://docs.microsoft.com/en-us/azure/automation/automation-starting-a-runbook) it as a regular Automation runbook.

## Notes

* If you import this runbook with the original name (**Update-AutomationAzureModulesForAccount**),
  it will override the internal runbook with this name. As a result, the imported runbook will
  run when the **Update Azure Modules** button is pushed or when this runbook is invoked directly
  via ARM API for this Automation account. If this is not what you want, specify a different name
  when importing this runbook.
* Only **Azure** and **AzureRM.\*** modules are currently supported. The new [Azure PowerShell Az modules](https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az) are not supported yet.
  Avoid starting this runbook on Automation accounts that contain Az modules.
* Before starting this runbook, make sure your Automation account has an [Azure Run As account credential](https://docs.microsoft.com/en-us/azure/automation/manage-runas-account) created.
* You can use this code as a regular PowerShell script instead of a runbook: just login to Azure
  using the [Connect-AzureRmAccount](https://docs.microsoft.com/en-us/powershell/module/azurerm.profile/connect-azurermaccount)
  command first, then pass `-Login $false` to the script.
* To use this runbook on the sovereign clouds, provide the appropriate value to the `AzureEnvironment`
  parameter. Please also make sure you read the
  [compatibility notes](https://docs.microsoft.com/en-us/azure/automation/automation-update-azure-modules#alternative-ways-to-update-your-modules).
* When facing compatibility issues, you may want to use specific older module versions instead of
  the latest available on the PowerShell Gallery. In this case, provide the required versions in
  the `ModuleVersionOverrides` parameter.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
