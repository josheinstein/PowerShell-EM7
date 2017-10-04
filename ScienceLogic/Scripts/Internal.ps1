##############################################################################
#.SYNOPSIS
# Builds a URI from several well-known components of a EM7 API URL.
##############################################################################
function CreateUri {
    
    [CmdletBinding()]
    param(

        # The resource type, such as device or organization.
        [Parameter()]
        [String]$Resource,

        # Specifies the ID of a resource if requesting a specific entity.
        # If not specified, the device index will be queried instead.
        [Parameter()]
        [String]$ID,

        # Specifies a limit on the number of returned results. If this parameter
        # is not specified, no results will be returned.
        [Parameter()]
        [Int32]$Limit,

        # The starting offset in the results to return.
        # If retrieving objects in pages of 100, you would specify 0 for page 1,
        # 100 for page 2, 200 for page 3, and so on.
        [Parameter()]
        [Int32]$Offset = 0,

        # True to request an expanded result, instead of a result containing
        # a list of links to resources.
        [Parameter()]
        [Boolean]$Extended,

        # The keys in this hashtable will be prefixed with 'filter.' and appended
        # to the query string for filtering on resource indexes.
        [Parameter()]
        [Hashtable]$Filter,

        # Optionally sorts the results by this field in ascending order, or if
        # the field is prefixed with a dash (-) in descending order.
        # You can also pipe the output to PowerShell's Sort-Object cmdlet, but
        # this parameter is processed on the server, which will affect how
        # results are paginated when there are more results than fit in a
        # single page.
        [Parameter()]
        [String]$OrderBy

    )

    $Query = @{}

    if ($Globals.HideFilterInfo) { $Query['hide_filterinfo'] = $Globals.HideFilterInfo }
    if ($Extended) { $Query['extended_fetch'] = 1 }
    if ($Limit) { $Query['limit'] = $Limit }
    if ($Offset) { $Query['offset'] = $Offset }
    if ($OrderBy) {
        if ($OrderBy -like '-*') { $Query["order.$($OrderBy.Substring(1))"] = 'DESC' }
        else { $Query["order.$OrderBy"] = 'ASC' }
    }

    foreach ($Name in $Filter.Keys) {
        $Query["filter.$Name"] = $Filter[$Name]
    }

    $URI = %New-Uri "$Resource/$ID" -BaseUri $Globals.ApiRoot -QueryString $Query
    Return $URI

}

##############################################################################
#.SYNOPSIS
# The ScienceLogic EM7 API returns multiple results as a single root object
# container whose properties are URIs and values are the actual object that
# we want. This is much more usable as an array, so this function simply
# enumerates the properties that are URIs and returns the values of those
# properties, essentially turning a JSON object into an array of its values.
##############################################################################
function UnrollArray {

    [CmdletBinding()]
    param(

        # The objects whose properties are to be enumerated and unrolled
        # into an array of those properties' values.
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [PSObject]$InputObject

    )

    if ($InputObject.result_set) {
        $InputObject = $InputObject.result_set
        
    }

    $AllKeys = @($InputObject | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name)
    $UriKeys = @($AllKeys -like '/api/*')
    if ($AllKeys.Count) {
        if ($AllKeys.Count -eq $UriKeys.Count) {
            $UriKeys | ForEach { 
                $Item = $InputObject.$_ 
                if ($_ -match '^(.*)/([A-Za-z0-9_\-\.]+)$') {
                    $TypeName = $Matches[1]
                    $ID = $Matches[2]
                    if ($ID -as [Int32]) { $ID = $ID -as [Int32] }
                    $Item | Add-Member -TypeName $TypeName
                    $Item | Add-Member NoteProperty __ID $ID
                    $Item | Add-Member NoteProperty __URI $_
                }
                Write-Output $Item
            }
        }
        else {
            # Not sure what this object is.
            # It has properties, but not all of them are URI keys
            # Just return it as-is.
            Write-Output $InputObject
        }
    }

}

##############################################################################
#.SYNOPSIS
# The ScienceLogic EM7 API returns objects that contain links to other
# resources. For example, a device has a link to its organization. This
# property is represented as a relative URI to the related object. This
# function takes an input object and one or more of these link property names
# to 'expand' by making HTTP requests for them and replacing the properties
# of the original object with the results of those HTTP requests.
# In other words, a device object that has an organization property which is
# a link to its organization will now have an organization property which is
# the organization object itself.
##############################################################################
function ExpandProperty {

    [CmdletBinding()]
    param(

        # The object that contains links to other objects to be expanded.
        [Parameter(Position=0)]
        [PSObject]$InputObject,

        # One or more property names to expand by making requests for those
        # objects.
        [Parameter(Position=1)]
        [String[]]$Property,

        # When ExpandProperty is being called on multiple objects (for example,
        # a list of devices in an organization), many or all of those objects
        # may have links that reference the same object. Rather than requesting
        # the object multiple times, a Hashtable can be created up front and
        # passed into each call to ExpandProperty. If the URI is found in the
        # hashtable as a key, that object will be returned immediately instead
        # of being requested again.
        # It is recommended that you do not reuse the cache between batches, 
        # unless there is a specific reason to do so.
        [Parameter()]
        [Hashtable]$Cache

    )

    if ($Cache -eq $Null) { $Cache  =@{} }

    foreach ($Prop in $Property) {

        Write-Verbose "Expanding: $Prop"

        $P,$S = $Prop -split '/'

        $URI = $Null

        if ($InputObject.$P -is [String]) {
            
            # URI is a simple property
            # ie. 'snmp_cred_id': '/api/credential/snmp/1'
            $URI = $InputObject.$P

        }
        elseif ($InputObject.$P -is [Array]) {

            if (!($InputObject.$P -notlike '/api/*')) {

                $URI = $InputObject.$P

                $InputObject.$P = @()

            }

        }
        else {

            # URI is a complex property
            # ie. "notes": {
            #        "URI": "/api/device/3066/note/?hide_filterinfo=1&limit=1000",
            #        "description": "Notes"
            # },

            if ($InputObject.$P.URI -is [String]) {
                $URI = $InputObject.$P.URI
            }

        }

        foreach ($U in $URI) {

            # First check the cache
            if (!$Cache[$U]) {
                # Not there? Go get it.
                $Cache[$U] = HttpInvoke (%New-Uri $U -BaseUri $Globals.ApiRoot -QueryString @{extended_fetch=1;limit=10}) | UnrollArray
            }

            if ($URI -is [Array]) {
                $InputObject.$P += $Cache[$U]
            }
            else {
                $InputObject.$P = $Cache[$U]
            }

        }

        # Are there subproperties to expand?
        if ($S.Length) {
            ExpandProperty ($InputObject.$P) ($S -join '/') -Cache:$Cache
        }

    }

}

##############################################################################
#.SYNOPSIS
# Checks to make sure that Connect-EM7 has been called. In other words, that
# we have an API root and credentials. Does not verify credentials.
##############################################################################
function EnsureConnected {
    
    if (!$Globals.ApiRoot -or !$Globals.Credentials) {
        Write-Error "Connect-EM7 must be called first."
    }

}

##############################################################################
#.SYNOPSIS
# Makes a HTTP request for a particular URL, passing in the required
# authentication headers and other global options used with the ScienceLogic
# EM7 REST API.
##############################################################################
function HttpInvoke {

    [CmdletBinding(DefaultParameterSetName="GET")]
    param(
        
        # The URI of the resource
        [Parameter(Position=0, Mandatory=$true)]
        [URI]$URI,

        # Specifies the HTTP verb to use.
        # The default is GET
        [Parameter(ParameterSetName="Advanced")]
        [String]$Method = "GET",

        # The POST data to include in the request.
        [Parameter(ParameterSetName="Advanced")]
        [String]$PostData,

        # Not currently implemented
        [Parameter()]
        [Switch]$ThrowIfNotFound

    )

    Write-Verbose "$Method $URI"

    [System.Net.HttpWebRequest]$Request = $Null
    [System.Net.HttpWebResponse]$Response = $Null
    [System.IO.Stream]$RequestStream = $Null
    [System.IO.StreamWriter]$RequestWriter = $Null
    [System.IO.Stream]$ResponseStream = $Null
    [System.IO.StreamReader]$ResponseReader = $Null

    try {

        $Cred    = $Globals.Credentials.GetNetworkCredential()
    
        $Request = [System.Net.HttpWebRequest]([System.Net.WebRequest]::Create($URI))
        $Request.Method = $Method
        $Request.Accept = 'application/json'
        $Request.Headers.Add('Authorization', "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Cred.UserName + ':' + $Cred.Password)))")

        if ($Globals.FormatResponse) {
            $Request.Headers.Add('x-em7-beautify-response', '1')
        }

        $Request.AllowAutoRedirect = $false

        if ($PostData) {
            $Request.ContentType = "application/json"
            $RequestStream = $Request.GetRequestStream()
            $RequestWriter = New-Object System.IO.StreamWriter ($RequestStream)
            $RequestWriter.Write($PostData)
            $RequestWriter.Flush()
            $RequestWriter.Close()
            $RequestStream.Close()
        }

        $Response = $Request.GetResponse()
        $ResponseStream = $Response.GetResponseStream()
        $ResponseReader = New-Object System.IO.StreamReader ($ResponseStream)

        [String]$JSON = $ResponseReader.ReadToEnd()

        $Result = ConvertFrom-Json $JSON

        Return $Result

    }
    finally {

        if ($RequestWriter) { $RequestWriter.Dispose() }
        if ($RequestStream) { $RequestStream.Dispose() }
        if ($ResponseReader) { $ResponseReader.Dispose() }
        if ($ResponseStream) { $ResponseStream.Dispose() }
        if ($Response) { $Response.Dispose() }

    }

}

##############################################################################
#.SYNOPSIS
# Verifies that the current user is an administrator and the process is
# currently elevated under UAC.
##############################################################################
function %Test-Administrator {

    try {
        
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal $Identity

        if ($Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { 
            return $true
        } 
        
    }
    finally {
        if ($Identity) { $Identity.Dispose() }
    }

}

##############################################################################
#.SYNOPSIS
# Creates a new URI based on the specified base and relative URI's.
#
#.EXAMPLE
# $Uri = New-Uri /images -BaseUri http://www.google.com
##############################################################################
function %New-Uri {

    [OutputType([System.Uri])]
    [CmdletBinding()]
    param (
    
        # A string that contains a valid URI. If -BaseUri is specified, this may be
        # relative to the BaseUri.
        [Alias('u')]
        [Parameter(Position=0, Mandatory=$true)]
        [String]$Uri,
        
        # The URI to use as the base upon which the Uri builds.
        [Alias('Base', 'b')]
        [Parameter()]
        [Uri]$BaseUri,
        
        # A list of key/value pairs that are appended to the URI's query string.
        [Alias('q')]
        [Parameter()]
        [Hashtable]$QueryString

    )

    if ($BaseUri) {
        $UriBuilder = New-Object UriBuilder(New-Object Uri($BaseUri,$Uri))
    }
    else {
        $UriBuilder = New-Object UriBuilder(New-Object Uri($Uri))
    }
    
    if ($QueryString.Count) {
        
        # Work around a bug in UriBuilder's Query property
        # which can result in redundant ? characters.
        [String]$Query = $UriBuilder.Query.TrimStart('?')

        foreach ($Key in $QueryString.Keys) {
            $Value = $QueryString[$Key]
            $Query += [String]::Concat(
                '&',
                [Uri]::EscapeDataString($Key),
                '=',
                [Uri]::EscapeDataString($Value)
            )
        }

        $UriBuilder.Query = $Query.TrimStart('&')

    }

    $UriBuilder.Uri

}
