##############################################################################
#.SYNOPSIS
# Stores the credentials for accessing the ScienceLogic EM7 API in-memory
# and tests the connection to the web service.
##############################################################################
function Connect-EM7 {

    [CmdletBinding()]
    param(

        # The API root URI
        [Parameter(Position=1, Mandatory=$true)]
        [Uri]$URI,

        # Specify this when you'll be using a HTTP debugger like Fiddler.
        # It will cause the JSON to be formatted with whitespace for easier
        # reading, but is more likely to result in errors with larger responses.
        [Parameter()]
        [Switch]$Formatted

    )

    # Force trailing slash
    if ($URI -notlike '*/') { $URI = "$URI/" }

    if (Test-Path $Globals.CredentialPath) { Remove-Item $Globals.CredentialPath }

    $Globals.ApiRoot = $URI
    $Globals.FormatResponse = $Formatted.IsPresent
    $Globals.Credentials = Get-Credential -Message 'Enter your ScienceLogic API credentials.'
    $Globals.Credentials | Add-Member NoteProperty URI $URI
    $Globals.Credentials | Add-Member NoteProperty FormatResponse $Formatted.IsPresent

    # Will throw not-authorized if the credentials are invalid
    HttpInvoke $URI | Out-Null

    $Globals.Credentials | Export-Clixml $Globals.CredentialPath

}

##############################################################################
#.SYNOPSIS
# Retrieves a specific EM7 object by its ID.
##############################################################################
function Get-EM7Object {

    [Alias('gslo')]
    [CmdletBinding()]
    param(

        # The name of the resource index to query.
        # See the documentation for value values.
        # Examples include, device, device_group, organization, account...
        [Parameter(Position=1, Mandatory=$true)]
        [String]$Resource,

        # The ID of a specific entity to retrieve.
        [Parameter(Position=2, Mandatory=$true)]
        [Int32[]]$ID,

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

        $FindArgs = @{
            Resource = $Resource
            ExpandProperty = $ExpandProperty
            Filter = @{}
            Limit = $ID.Length
        }

        if ($ID) {
            $FindArgs.Filter['_id.in'] = $ID -join ','
        }

        Find-EM7Object @FindArgs

    }

}

##############################################################################
#.SYNOPSIS
# Queries the specified resource index for resources matching an optional
# filter specification.
##############################################################################
function Find-EM7Object {

    [Alias('fslo')]
    [CmdletBinding()]
    param(

        # The name of the resource index to query.
        # See the documentation for value values.
        # Examples include, device, device_group, organization, account...
        [Parameter(Position=1, Mandatory=$true)]
        [String]$Resource,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{organization=6}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

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

        $UriArgs = @{
            Resource = $Resource
            Filter = $Filter
            Limit = $Limit
            Offset = $Offset
            Extended = $true
            OrderBy = $OrderBy
        }

        if ($UriArgs.Limit -gt $Globals.DefaultPageSize) {
            $UriArgs.Limit = $Globals.DefaultPageSize
        }

        $OutputCount = 0

        do {

            $URI = CreateUri @UriArgs
        
            $Response = HttpInvoke $URI
        
            $TotalMatched = $Response.total_matched -as [Int32]
            $TotalReturned = $Response.total_returned -as [Int32]

            $Result = @($Response | UnrollArray)
            if ($ExpandProperty.Length) {
                $Cache = @{}
                foreach ($Obj in $Result) {
                    ExpandProperty $Obj $ExpandProperty -Cache:$Cache
                }
            }

            if ($Result.Length) {
            
                Write-Output $Result

                $OutputCount += $Result.Length
                $UriArgs.Offset += $Result.Length

                if ($UriArgs.Offset + $UriArgs.Limit -gt $Limit) {
                    $UriArgs.Limit = $Limit - $UriArgs.Offset
                }

            }
            else {
                break
            }

        } while ($OutputCount -lt $Limit -and $OutputCount -lt $TotalMatched);

    }

}

##############################################################################
#.SYNOPSIS
# Updates the properties of a EM7 object at the specified URI. Only the
# properties specified in the -InputObject parameter will be updated.
##############################################################################
function Set-EM7Object {
    
    [Alias('sslo')]
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(

        # The relative or absolute URI of the resource, such as
        # /api/organization/1 or https://servername/api/device/9.
        [Alias("__URI")]
        [ValidateNotNull()]
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Uri]$URI,

        # A custom object (which may be a Hashtable or other PSObject
        # such as a deserialized JSON object or PSCustomObject.)
        [ValidateNotNull()]
        [Parameter(Position=1)]
        [PSObject]$InputObject,

        # If specified, the output of the update will be deserialized
        # and written to the pipeline.
        [Parameter()]
        [Switch]$PassThru

    )

    begin {

        EnsureConnected -ErrorAction Stop

    }

    process {

        # Cmdlet takes an absolute or relative URL
        # If relative was specified, make it absolute against the API root
        if (!$URI.IsAbsoluteUri) {
            $URI = New-Object Uri ($Globals.ApiRoot, $URI.OriginalString)
        }

        if ($InputObject -is [Hashtable]) {

            if ($InputObject.Count) {

                $Compress = !$Globals.FormatResponse

                # Typically Hashtables were passed in as an argument
                # They are expected to only contain the properties we want to
                # update. No scrubbing will be done.
                $JSON = ConvertTo-Json -InputObject:$InputObject -Compress:$Compress

            }
            else {
                Write-Warning "No properties were updated."
                return
            }

        }
        else {

            # If it's another PSObject, it's probably been piped in from
            # another command such as Get-EM7Object and modified.
            # We need to remove 

            $Properties = @(
                $InputObject | 
                Get-Member -MemberType NoteProperty | 
                Where Name -NotLike __* | 
                Select -ExpandProperty Name
            )

            if ($Properties.Length) {
                $InputObject = $InputObject | Select $Properties
                $JSON = $InputObject | ConvertTo-Json
            }
            else {
                Write-Warning "No writable properties specified."
                return
            }

        }

        if ($PSCmdlet.ShouldProcess($URI, "POST: $JSON")) {

            $Result = HttpInvoke $URI -Method POST -PostData $JSON

            if ($PassThru) {

                if ($URI.AbsolutePath -match '^(.*)/([A-Za-z0-9_\-\.]+)$') {
                    $TypeName = $Matches[1]
                    $ID = $Matches[2]
                    if ($ID -as [Int32]) { $ID = $ID -as [Int32] }
                    $Result | Add-Member -TypeName $TypeName
                    $Result | Add-Member NoteProperty __ID $ID
                    $Result | Add-Member NoteProperty __URI $URI.AbsolutePath
                }

                Write-Output $Result

            }

        }

    }

}
