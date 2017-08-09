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

    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the device group with the specified ID
        [Parameter(ParameterSetName='ID', Position=1, Mandatory=$true)]
        [Int32[]]$ID,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{state='PA'}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

        # If specified, device groups are searched based on the name
        # Wildcards can be used at either end of the name to check for
        # partial matches.
        [Parameter(ParameterSetName='Advanced')]
        [String]$Name,

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
        [String[]]$ExpandProperty

    )

    begin {
    
        EnsureConnected -ErrorAction Stop

    }

    process {

        if ($Filter -eq $Null) { $Filter = @{} }

        if ($Name) {
            $Operator = ''
            if ($Name.StartsWith('*') -and $Name.EndsWith('*')) { $Operator = '.contains' }
            elseif ($Name.StartsWith('*')) { $Operator = '.ends_with' }
            elseif ($Name.EndsWith('*')) { $Operator = '.begins_with' }
            $Filter["name$Operator"] = $Name.Trim('*')
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ID' {
                Get-EM7Object device_group -ID:$ID -ExpandProperty:$ExpandProperty
            }
            'Advanced' {
                Find-EM7Object device_group -Filter:$Filter -Limit:$Limit -Offset:$Offset -OrderBy:$OrderBy -ExpandProperty:$ExpandProperty
            }
        }

    }

}

##############################################################################
#.SYNOPSIS
# Gets a list of devices that are members of the specified device group.
##############################################################################
function Get-EM7DeviceGroupMember {

    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the device group with the specified ID
        [Alias('__DeviceGroupID')]
        [Parameter(ParameterSetName='ID', Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Int32[]]$ID,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{state='PA'}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

        # If specified, device groups are searched based on the name
        # Wildcards can be used at either end of the name to check for
        # partial matches.
        [Parameter(ParameterSetName='Advanced')]
        [String]$Name,

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

        # If specified, device groups that are members of this device group will
        # be recursively expanded as well.
        [Parameter()]
        [Switch]$Recurse

    )

    begin {
    
        EnsureConnected -ErrorAction Stop

    }

    process {

        $DeviceGroups = @()
        if ($ID)   { $DeviceGroups += @(Get-EM7DeviceGroup -ID:$ID) }
        if ($Name) { $DeviceGroups += @(Get-EM7DeviceGroup -Name:$Name) }

        foreach ($DeviceGroup in $DeviceGroups) {

            $URI = CreateUri "device_group/$($DeviceGroup.__ID)/expanded_devices"
            $Response = HttpInvoke $URI
            
            $GroupIDs = [Int32[]]($DeviceGroup.groups -replace '.*/(\d+)$','$1')
            $MemberIDs = [Int32[]]($Response -replace '.*/(\d+)$','$1')

            if ($MemberIDs) {
                Get-EM7Object device -ID:$MemberIDs -ExpandProperty:$ExpandProperty
            }

            if ($Recurse -and $GroupIDs) {
                Get-EM7DeviceGroupMember -ID:$GroupIDs -ExpandProperty:$ExpandProperty
            }

        }

    }

}

##############################################################################
#.SYNOPSIS
# Adds a device as a static member of the specified device group.
##############################################################################
function Add-EM7DeviceGroupMember {

    [CmdletBinding(DefaultParameterSetName='Name', SupportsShouldProcess=$true)]
    param(

        # The name of an existing device group.
        # This must match one and only one device group, otherwise use ID.
        [Parameter(ParameterSetName='Name', Position=1, Mandatory=$true)]
        [String]$Name,

        # The ID of an existing device group.
        [Parameter(ParameterSetName='ID', Mandatory=$true)]
        [Int32]$ID,

        # A device piped from the output of another command (such as Get-EM7Device).
        # This property must be a device and have a corresponding device URI.
        [Parameter(ValueFromPipeline=$true)]
        [PSObject[]]$Device

    )

    begin {

        EnsureConnected -ErrorAction Stop

        $AddedIDs = @()
        $AddedDevices = @()

        $DeviceGroup = $Null
        $DeviceGroupName = $Null
        $DeviceGroupID = $Null
        $DeviceGroupURI = $Null

        # The device group to add devices to can be supplied by ID or name
        # Use the appropriate command to get the device group object

        if ($ID) { $DeviceGroup = Get-EM7Object -Resource device_group -ID $ID -ErrorAction 0 }
        elseif ($Name) { $DeviceGroup = Find-EM7Object -Resource device_group -Filter @{name=$Name} -Limit 2 }

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
                if ($DID -is [PSObject]) {
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
