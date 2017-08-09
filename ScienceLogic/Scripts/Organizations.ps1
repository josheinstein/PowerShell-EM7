##############################################################################
#.SYNOPSIS
# Get a ScienceLogic EM7 organization entity.
##############################################################################
function Get-EM7Organization {
    
    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the organization with the specified ID
        [Parameter(ParameterSetName='ID', Position=0, Mandatory=$true)]
        [Int32[]]$ID,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{state='PA'}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

        # If specified, organizations are searched based on the company name
        # Wildcards can be used at either end of the name to check for
        # partial matches.
        [Alias('Name')]
        [Parameter(ParameterSetName='Advanced')]
        [String]$Company,

        # Searches for organizations with the specified billing_id.
        [Alias('billing_id')]
        [Parameter(ParameterSetName='Advanced')]
        [String[]]$BillingID,

        # Searches for organizations with the specified crm_id.
        [Alias('crm_id')]
        [Parameter(ParameterSetName='Advanced')]
        [String[]]$CrmID,

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

        if ($Company) {
            $Operator = ''
            if ($Company.StartsWith('*') -and $Company.EndsWith('*')) { $Operator = '.contains' }
            elseif ($Company.StartsWith('*')) { $Operator = '.ends_with' }
            elseif ($Company.EndsWith('*')) { $Operator = '.begins_with' }
            $Filter["company$Operator"] = $Company.Trim('*')
        }

        if ($BillingID) { $Filter['billing_id.in'] = $BillingID -join ',' }
        if ($CrmID) { $Filter['crm_id.in'] = $CrmID -join ',' }

        switch ($PSCmdlet.ParameterSetName) {
            'ID' {
                Get-EM7Object organization -ID:$ID -ExpandProperty:$ExpandProperty
            }
            'Advanced' {
                Find-EM7Object organization -Filter:$Filter -Limit:$Limit -Offset:$Offset -OrderBy:$OrderBy -ExpandProperty:$ExpandProperty
            }
        }

    }

}
