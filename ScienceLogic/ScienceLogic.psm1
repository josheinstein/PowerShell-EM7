##############################################################################
# SUMMARY
# PowerShell commands for working with the ScienceLogic EM7 API.
#
# AUTHOR
# Josh Einstein
# Tom Robijns
##############################################################################

$Globals = @{
    ApiRoot         = $Null
    Credentials     = $Null
    FormatResponse  = $false
    HideFilterInfo  = 1
    DefaultLimit    = 100
	DefaultPageSize = 500
    CredentialPath  = "${ENV:TEMP}\slcred.xml"
    IgnoreSSLErrors = $false
	UriPattern      = '^(?<t>/api/(?<r>\w+))/(?<id>\d+)$'
}

if (Test-Path $Globals.CredentialPath) {
    $Globals.Credentials = Import-Clixml $Globals.CredentialPath -ErrorAction SilentlyContinue
    $Globals.ApiRoot = $Globals.Credentials.URI
	$Globals.FormatResponse = $Globals.Credentials.FormatResponse
}

. $PSScriptRoot\Scripts\Internal.ps1
. $PSScriptRoot\Scripts\Core.ps1
. $PSScriptRoot\Scripts\Organizations.ps1
. $PSScriptRoot\Scripts\Devices.ps1
. $PSScriptRoot\Scripts\DeviceGroups.ps1
. $PSScriptRoot\Scripts\Alerts.ps1

Export-ModuleMember -Function @('Connect-EM7', 'Get-EM7Device', 'Get-EM7DeviceGroup','Get-EM7DeviceGroupMember','Get-EM7DeviceGroupMembership', 'Submit-EM7Alert', 'Add-EM7DeviceGroupMember', 'Get-EM7Object' )
