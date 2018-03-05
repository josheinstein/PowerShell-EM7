Function Submit-EM7Alert {
<#
.SYNOPSIS
 Sends an alert message to a specific device in ScienceLogic

.Description
 Submit-EM7Alert required a EM7 device as input parameter and a message that needs to be added to this device.

.EXAMPLE
 $Did = Get-EM7Device -ID 1952
 Submit-EM7Alert -Device $Did -Message 'You have been pwned'
 
 The first command gets a specific device from sciencelogic.
 The second command adds the entry 'You have been pwned' to the log of the device. If an event policy is found matching this message, an event will popup

.EXAMPLE
 $Devices = Get-EM7Device -Filter {organization=9}
 $Devices | Submit-EM7Alert -Message 'Message to all devices of organization 9'

 The first command gets all devices in EM7 aligned to organization 9
 The second command submits the same alert to all devices
#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
        [Parameter(Mandatory=$true,Position=0, ValueFromPipeLine=$true)]
        [ValidateScript({if ($_.__URI -ne $null) { $true } else { throw "Passed PSObject $_ is not a EM7 device"; $false} })]
        [PSObject]$Device,

		[Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$Message
	)
	Begin {
        EnsureConnected -ErrorAction Stop
	}

	Process {
		if ($PSCmdlet.ShouldProcess("EM7","message '$($Message)' will be sent to $($Device.Name)") ) {
            $fi = $globals.HideFilterInfo
            $Globals.Remove('HideFilterInfo')
            $URI = CreateUri -Resource 'alert'
            $Reponse = HttpInvoke $URI -Method 'POST' -PostData "{""aligned_resource"":""$($Device.__URI)"",""message_time"":""0"",""message"":""$($Message)""}"
            $Globals.Add('HideFilterInfo',$fi)

        }
	}
}