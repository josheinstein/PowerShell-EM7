##############################################################################
#.SYNOPSIS
# Gets information about a device group by its name or ID.
#
#.DESCRIPTION
# Note, that since device groups may contain rules or other device groups,
# this function does not necessarily represent every device included in the
# group implicitly. For that, you should use the Get-EM7DeviceGroupMember
# function.
##############################################################################
function Get-EM7DeviceGroup {

    [CmdletBinding(DefaultParameterSetName='ByID')]
    param(

        # If specified, retrieves the device group with the specified ID, URI, or Name.
        # When using name match, wildcards can be used at either end of the name
		# to check for partial matches.
        [Alias('Name')]
		[Parameter(ParameterSetName='ByID', Position=0)]
        [String]$ID,

        # If specified, retrieves the device groups that are children of the specified
		# parent device group.
		[Parameter(ParameterSetName='ByParent', Mandatory=$true)]
		[String]$Parent,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{state='PA'}
        [Parameter()]
        [Hashtable]$Filter = @{},

        # Limits the results to the specified number. The default is 1000.
        [Parameter()]
        [Int32]$Limit = $Globals.DefaultLimit,

        # The starting offset in the results to return.
        # If retrieving objects in pages of 100, you would specify 0 for page 1,
        # 100 for page 2, 200 for page 3, and so on.
        [Parameter()]
        [Int32]$Offset = 0,

        # Optionally sorts the results by this field in ascending order, or if
        # the field is prefixed with a dash (-) in descending order.
        # You can also pipe the output to PowerShell's Sort-Object cmdlet, but
        # this parameter is processed on the server, which will affect how
        # results are paginated when there are more results than fit in a
        # single page.
        [Parameter()]
        [String]$OrderBy,

        # Specifies one or more property names that ordinarily contain a link
        # to a related object to automatically retrieve and place in the 
        # returned object.
        [Parameter()]
        [String[]]$ExpandProperty,

		# If specified, the cache will be checked for device group data before
		# making a call to the server for a given device group id.
		# This is primarily designed to be used internally, when functions are being called
		# repeatedly, such as in recursion scenarios, which may result in duplicated lookups.
		[Parameter()]
		[Hashtable]$Cache = @{}

    )

    begin {
    
        EnsureConnected -ErrorAction Stop

    }

    process {

		if ($PSCmdlet.ParameterSetName -eq 'ByID') {

			if ($ID) {
				if ($ID -as [Int32]) {
					# Treat it as an ID #
					Get-EM7Object device_group -ID:$ID -ExpandProperty:$ExpandProperty
					Return
				}
				elseif ($ID -match $Globals.UriPattern -and $Matches.r -eq 'device_group') {
					# Treat it as a URI
					$DeviceGroup = $Cache[$ID]
					if (!$DeviceGroup) {
						$DeviceGroup = Get-EM7Object -URI:$ID -ExpandProperty:$ExpandProperty
						$Cache[$ID] = $DeviceGroup
					}
					if ($DeviceGroup) { $DeviceGroup }
					Return
				}
				else {
					# Treat it as a name
					$Operator = ''
					if ($ID.StartsWith('*') -and $ID.EndsWith('*')) { $Operator = '.contains' }
					elseif ($ID.StartsWith('*')) { $Operator = '.ends_with' }
					elseif ($ID.EndsWith('*')) { $Operator = '.begins_with' }
					$Filter["name$Operator"] = $ID.Trim('*')
				}
			}

			Find-EM7Object device_group -Filter:$Filter -Limit:$Limit -Offset:$Offset -OrderBy:$OrderBy -ExpandProperty:$ExpandProperty |
			ForEach-Object { $Cache[$_.__URI] = $_; $_ } |
			Sort-Object Name

		}
		elseif ($PSCmdlet.ParameterSetName -eq 'ByParent') {

			$ParentGroups = @(Get-EM7DeviceGroup -ID:$Parent -Filter @{'group_count.min'=1} -Cache:$Cache)
			Get-EM7Object -URI:$ParentGroups.groups -ExpandProperty:$ExpandProperty |
			ForEach-Object { $Cache[$_.__URI] = $_; $_ } |
			Sort-Object Name

		}

    }

}

##############################################################################
#.SYNOPSIS
# Gets a list of devices that are members of the specified device group.
##############################################################################
function Get-EM7DeviceGroupMember {

    [CmdletBinding()]
    param(

        # The device group ID, URI, or Name.
        # When using name match, wildcards can be used at either end of the name
		# to check for partial matches.
        [Alias('Name', '__DeviceGroupID')]
        [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$ID,

        # Specifies one or more property names that ordinarily contain a link
        # to a related object to automatically retrieve and place in the 
        # returned object.
        [Parameter()]
        [String[]]$ExpandProperty,

		# Returns only the Device URIs, and does not retrieve the device details.
		[Switch]$Quick,

        # If specified, device groups that are members of this device group will
        # be recursively expanded as well.
        [Parameter()]
        [Switch]$Recurse,

		# If specified, the cache will be checked for device group membership data before
		# making a call to the server for a given device group id.
		# This is primarily designed to be used internally, when functions are being called
		# repeatedly, such as in recursion scenarios, which may result in duplicated lookups.
		[Parameter()]
		[Hashtable]$Cache = @{}

    )

    begin {
    
        EnsureConnected -ErrorAction Stop

    }

    process {

	    $DeviceGroups = @(Get-EM7DeviceGroup -ID:$ID -Cache:$Cache)

        foreach ($DeviceGroup in $DeviceGroups) {

            $URI = CreateUri "device_group/$($DeviceGroup.__ID)/expanded_devices"
            $DeviceIDs = $Cache[$URI.AbsolutePath]
			if (!$DeviceIDs) {
				$DeviceIDs = HttpInvoke $URI
				$Cache[$URI.AbsolutePath] = $DeviceIDs
			}
            
            if ($DeviceIDs.Length) {
				if ($Quick) {
					Write-Output $DeviceIDs
				}
				else {
					Get-EM7Object -URI:$DeviceIDs -ExpandProperty:$ExpandProperty
				}
            }

            if ($Recurse) {
				foreach ($GroupID in $DeviceGroup.groups) {
					Get-EM7DeviceGroupMember -ID:$GroupID -ExpandProperty:$ExpandProperty -Quick:$Quick -Recurse:$Recurse -Cache:$Cache
				}
            }

        }

    }

}

##############################################################################
#.SYNOPSIS
# Adds a device as a static member of the specified device group.
##############################################################################
function Add-EM7DeviceGroupMember {

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(

        # The name of an existing device group.
        # This must match one and only one device group, otherwise use ID.
        [Alias('ID', 'Name')]
		[Parameter(Position=0, Mandatory=$true)]
        [String]$Group,

        # A device piped from the output of another command (such as Get-EM7Device).
        # This property must be a device and have a corresponding device URI.
        [Parameter(ValueFromPipeline=$true)]
        [PSObject[]]$Device

    )

    begin {

        EnsureConnected -ErrorAction Stop

        $AddedIDs = @()
        $AddedDevices = @()

        $DeviceGroup = Get-EM7DeviceGroup -ID:$Group -Limit 2
        $DeviceGroupName = $Null
        $DeviceGroupID = $Null
        $DeviceGroupURI = $Null

        if ($DeviceGroup -eq $Null -or $DeviceGroup.Count -eq 0) {
            # They specified a device group id or name and no matching
            # device group was found.
            $DeviceGroup = $Null
            Write-Error "No matching device groups."
            Return
        }

        if ($DeviceGroup.Count -gt 1) {
            # They specified a device group name and more than one matched
            $DeviceGroup = $Null
            Write-Error "More than one matching device group."
            Return
        }

        $DeviceGroupName = $DeviceGroup.Name
        $DeviceGroupID = $DeviceGroup.__ID
        $DeviceGroupURI = $DeviceGroup.__URI

        Write-Verbose "Device Group: $DeviceGroupName ($DeviceGroupURI)"
        
        if ($DeviceGroup.devices) {
            Write-Verbose "Initial Devices: $(($DeviceGroup.devices | Split-Path -Leaf) -join ', ')"
        }
        else {
            Write-Verbose "Initial Devices: (none)"
        }

    }

    process {

        if ($DeviceGroup) {

            foreach ($D in $Device) {

                $DID = $D

                # If a device object was used as input instead of a URI or ID,
                # make sure we extract its __URI
                if ($DID.__URI) {
                    $DID = $DID.__URI
                }

                # Normalize integer IDs to URIs
                if ($DID -as [Int32]) {
                    $DID = "/api/device/$DID"
                }

                # Make sure URI represents a device
                if ($DID -notmatch '^/api/device/\d+$') {
                    Write-Error "Expected input: $D"
                    continue
                }

                # Check if device group already contains device id
                if ($DeviceGroup.devices -contains $DID) {
                    
                    Write-Verbose "    Device Group $DeviceGroupURI already contains $DID"

                }
                else {

                    Write-Verbose "    Add Device: $DID"

                    $AddedDevices += $D
                    $AddedIDs += $DID

                }

            }

        }

    }

    end {

        # Changes are collected throughout the pipeline invocation and
        # only pushed up to the server at the end.
        # Double check we have a device group and changes were actually made.
        # Only push the devices property, rather than the entire object.

        if ($DeviceGroup -and $AddedIDs.Count) {

            # Fetch the device group again
            # Since we have to specify all members, it's possible that the member list
            # has changed before we started. This will minimize issues due to concurrency.
            if ($DeviceGroup = Get-EM7Object -Resource device_group -ID:$DeviceGroupID) {

                $DeviceGroup.devices += $AddedIDs

                Write-Verbose "Final Devices: $(($DeviceGroup.devices | Split-Path -Leaf) -join ', ')"

                if ($PSCmdlet.ShouldProcess($DeviceGroupURI, "Update Device Group")) {

                    Set-EM7Object -URI:$DeviceGroupURI @{devices=$DeviceGroup.devices}

                }

                Write-Output $AddedDevices

            }

        }

    }

}

<#
	.SYNOPSIS
	Gets the devices groups that the specified device is a member of.

	.DESCRIPTION
	There is no API operation that returns the device group membership
	for a given device, so this function must get every device group
	in the system and index the devices. If there are a large number of
	devices or device groups in the system, this could potentially be
	a long process.
#>
function Get-EM7DeviceGroupMembership {

    [CmdletBinding()]
    [OutputType([PSObject])]
    param (

        # The ID, URL, or object representing the device whose membership to check.
        [Alias('__DeviceID')]
		[Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$Device

	)

	begin {

		$ProgID = Get-Random -Minimum 100000
		Write-Progress "Loading device groups..." -Id:$ProgID

		$Cache = @{}
		$DeviceGroupCache = @(Get-Em7DeviceGroup -Limit 999999 -Cache:$Cache)
		foreach ($DeviceGroup in $DeviceGroupCache) {
			$DeviceGroup.devices = @(Get-EM7DeviceGroupMember -ID $DeviceGroup.__URI -Recurse -Quick -Cache:$Cache)
			$DeviceGroup.deviceCount = $DeviceGroup.devices.Count
		}

		Write-Progress "Done" -Id:$ProgID -Completed

	}

	process {

		$DID = $Null

		# We need a URI.
		# If Device object was passed in, get its URI.
		if ($Device.__URI) {
			$DID = $Device.__URI
		}
		elseif ($Device -as [Int32]) {
			$DID = "/api/device/$Device"
		}
		elseif ($Device -match $Globals.UriPattern -and $Matches.t -eq 'device') {
			$DID = $Device
		}
		else {
			Write-Error "Unsupported Device parameter: $Device"
		}

		if ($DID) {

			$DeviceGroupCache | Where-Object { $_.devices -contains $DID }

		}

	}

	end {

	}

}