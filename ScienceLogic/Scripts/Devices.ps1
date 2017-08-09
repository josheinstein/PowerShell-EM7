##############################################################################
#.SYNOPSIS
# Get a ScienceLogic EM7 device entity.
##############################################################################
function Get-EM7Device {
    
    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the device with the specified ID
        [Parameter(ParameterSetName='ID', Position=0, Mandatory=$true)]
        [Int32[]]$ID,

        # If specified, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{organization=6}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

        # If specified, devices in the given organization are searched.
        [Alias('__OrganizationID')]
        [Parameter(ParameterSetName='Advanced', ValueFromPipelineByPropertyName=$true)]
        [Int32[]]$Organization,

        # If specified, devices with the given IP address are searched.
        # Wildcards are allowed.
        [Parameter(ParameterSetName='Advanced')]
        [String]$IP,

        # Limits the results to the specified number. The default is 1000.
        [Parameter(ParameterSetName='Advanced')]
        [Int32]$Limit = $Globals.DefaultLimit,

        # The starting offset in the results to return.
        # If retrieving objects in pages of 100, you would specify 0 for page 1,
        # 100 for page 2, 200 for page 3, and so on.
        [Parameter(ParameterSetName='Advanced')]
        [Int32]$Offset = 0,

        # Optionally sorts the results by this field in ascending order, or if
        # the field is prefixed with a dash (-) in descending order.
        # You can also pipe the output to PowerShell's Sort-Object cmdlet, but
        # this parameter is processed on the server, which will affect how
        # results are paginated when there are more results than fit in a
        # single page.
        [Parameter(ParameterSetName='Advanced')]
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

        if ($Organization.Length) {
            $Filter['organization.in'] = $Organization -join ','
        }

        if ($IP) {
            $Operator = ''
            if ($IP.StartsWith('*') -and $IP.EndsWith('*')) { $Operator = '.contains' }
            elseif ($IP.StartsWith('*')) { $Operator = '.ends_with' }
            elseif ($IP.EndsWith('*')) { $Operator = '.begins_with' }
            $Filter["ip$Operator"] = $IP.Trim('*')
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ID' {
                Get-EM7Object device -ID:$ID -ExpandProperty:$ExpandProperty
            }
            'Advanced' {
                Find-EM7Object device -Filter:$Filter -Limit:$Limit -Offset:$Offset -OrderBy:$OrderBy -ExpandProperty:$ExpandProperty
            }
        }

    }

}
