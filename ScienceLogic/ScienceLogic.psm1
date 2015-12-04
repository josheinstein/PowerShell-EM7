##############################################################################
# SUMMARY
# PowerShell commands for working with the ScienceLogic EM7 API.
#
# AUTHOR
# Josh Einstein
##############################################################################

$Globals = @{
    ApiRoot         = $Null
    Credentials     = $Null
    FormatResponse  = $true
    HideFilterInfo  = 1
    DefaultLimit    = 1000
    CredentialPath  = "${ENV:TEMP}\slcred.xml"
}

if (Test-Path $Globals.CredentialPath) {
    $Globals.Credentials = Import-Clixml $Globals.CredentialPath -ErrorAction 0
    $Globals.ApiRoot = $Globals.Credentials.URI
}

##############################################################################
# PUBLIC FUNCTIONS
##############################################################################


##############################################################################
#.SYNOPSIS
# Stores the credentials for accessing the ScienceLogic EM7 API in-memory
# and tests the connection to the web service.
##############################################################################
function Connect-EM7 {

    [OutputType([PSObject])]
    [CmdletBinding()]
    param(

        # The API root URI
        [Parameter(Position=1, Mandatory=$true)]
        [Uri]$URI

    )

    if (Test-Path $Globals.CredentialPath) { Remove-Item $Globals.CredentialPath }

    $Globals.ApiRoot = $URI
    $Globals.Credentials = Get-Credential -Message 'Enter your ScienceLogic API credentials.'
    $Globals.Credentials | Add-Member NoteProperty URI $URI

    # Will throw not-authorized if the credentials are invalid
    HttpGet $URI | Out-Null

    $Globals.Credentials | Export-Clixml $Globals.CredentialPath

}

##############################################################################
#.SYNOPSIS
# Retrieves a specific EM7 object by its ID.
##############################################################################
function Get-EM7Object {

    [CmdletBinding()]
    param(

        # The name of the resource index to query.
        # See the documentation for value values.
        # Examples include, device, device_group, organization, account...
        [Parameter(Position=1, Mandatory=$true)]
        [String]$Resource,

        # The ID of a specific entity to retrieve.
        [Parameter(Position=2, Mandatory=$true)]
        [Int32]$ID,

        # Specifies one or more property names that ordinarily contain a link
        # to a related object to automatically retrieve and place in the 
        # returned object.
        [Parameter()]
        [String[]]$ExpandProperty

    )

    $UriArgs = @{
        ID = $ID
        Resource = $Resource
        Extended = $true
    }
    
    $URI = CreateUri @UriArgs
    $Result = HttpGet $URI
    if ($ExpandProperty.Length) {
        $Cache = @{}
        foreach ($Obj in @($Result)) {
            ExpandProperty $Obj $ExpandProperty -Cache:$Cache
        }
    }

    Return $Result

}

##############################################################################
#.SYNOPSIS
# Queries the specified resource index for resources matching an optional
# filter specification.
##############################################################################
function Find-EM7Object {

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

        # Specifies one or more property names that ordinarily contain a link
        # to a related object to automatically retrieve and place in the 
        # returned object.
        [Parameter()]
        [String[]]$ExpandProperty

    )

    $UriArgs = @{
        Resource = $Resource
        Filter = $Filter
        Limit = $Limit
        Offset = $Offset
        Extended = $true
    }

    $URI = CreateUri @UriArgs
    $Result = HttpGet $URI
    if ($ExpandProperty.Length) {
        $Cache = @{}
        foreach ($Obj in @($Result)) {
            ExpandProperty $Obj $ExpandProperty -Cache:$Cache
        }
    }

    Return $Result

}

##############################################################################
#.SYNOPSIS
# Get a ScienceLogic EM7 device entity.
##############################################################################
function Get-EM7Device {
    
    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the device with the specified ID
        [Parameter(ParameterSetName='ID', Position=1, Mandatory=$true)]
        [Int32]$ID,

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

        # Specifies one or more property names that ordinarily contain a link
        # to a related object to automatically retrieve and place in the 
        # returned object.
        [Parameter()]
        [String[]]$ExpandProperty

    )

    switch ($PSCmdlet.ParameterSetName) {
        'ID' {
            Get-EM7Object device $ID
        }
        'Advanced' {
            Find-EM7Object device @PSBoundParameters
        }
    }

}

##############################################################################
#.SYNOPSIS
# Get a ScienceLogic EM7 organization entity.
##############################################################################
function Get-EM7Organization {
    
    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the organization with the specified ID
        [Parameter(ParameterSetName='ID', Position=1, Mandatory=$true)]
        [Int32]$ID,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{state='PA'}
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

        # Specifies one or more property names that ordinarily contain a link
        # to a related object to automatically retrieve and place in the 
        # returned object.
        [Parameter()]
        [String[]]$ExpandProperty

    )

    switch ($PSCmdlet.ParameterSetName) {
        'ID' {
            Get-EM7Object organization $ID
        }
        'Advanced' {
            Find-EM7Object organization @PSBoundParameters
        }
    }

}

##############################################################################
# PRIVATE FUNCTIONS
##############################################################################

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
        [Hashtable]$Filter

    )

    $Query = @{}

    if ($Globals.HideFilterInfo) { $Query['hide_filterinfo'] = $Globals.HideFilterInfo }
    if ($Extended) { $Query['extended_fetch'] = 1 }
    if ($Limit) { $Query['limit'] = $Limit }
    if ($Offset) { $Query['offset'] = $Offset }

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
        [Parameter(Position=1)]
        [PSObject]$InputObject

    )

    $UriKeys = @($InputObject | Get-Member -Name '/api/*' | Select -ExpandProperty Name)
    if ($UriKeys.Count) {
        $UriKeys | ForEach { Write-Output $InputObject.$_ }
    }
    else {
        Write-Output $InputObject
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
        [Parameter(Position=1)]
        [PSObject]$InputObject,

        # One or more property names to expand by making requests for those
        # objects.
        [Parameter(Position=2)]
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

    foreach ($P in $Property) {

        $URI = $Null

        if ($InputObject.$P -is [String]) {
            
            # URI is a simple property
            # ie. 'snmp_cred_id': '/api/credential/snmp/1'
            $URI = $InputObject.$P

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

        if ($URI) {

            # First check the cache
            if (!$Cache[$URI]) {
                # Not there? Go get it.
                $Cache[$URI] = HttpGet (%New-Uri $URI -BaseUri $Globals.ApiRoot -QueryString @{extended_fetch=1})
            }

            $InputObject.$P = $Cache[$URI]

        }

    }

}


##############################################################################
#.SYNOPSIS
# Makes a HTTP GET request for a particular URL, passing in the required
# authentication headers and other global options used with the ScienceLogic
# EM7 REST API.
##############################################################################
function HttpGet {

    [CmdletBinding()]
    param(
        
        # The URI of the resource
        [Parameter(Position=1, Mandatory=$true)]
        [URI]$URI,

        # Not currently implemented
        [Parameter()]
        [Switch]$ThrowIfNotFound

    )

    [System.Net.HttpWebRequest]$Request = $Null
    [System.Net.HttpWebResponse]$Response = $Null
    [System.IO.Stream]$ResponseStream = $Null
    [System.IO.StreamReader]$ResponseReader = $Null

    try {

        $Cred    = $Globals.Credentials.GetNetworkCredential()
    
        $Request = [System.Net.HttpWebRequest]([System.Net.WebRequest]::Create($URI))
        $Request.Method = 'GET'
        $Request.Accept = 'application/json'
        $Request.Headers.Add('Authorization', "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Cred.UserName + ':' + $Cred.Password)))")

        if ($Globals.FormatResponse) {
            $Request.Headers.Add('x-em7-beautify-response', '1')
        }

        $Request.AllowAutoRedirect = $false

        $Response = $Request.GetResponse()
        $ResponseStream = $Response.GetResponseStream()
        $ResponseReader = New-Object System.IO.StreamReader ($ResponseStream)

        [String]$JSON = $ResponseReader.ReadToEnd()

        $Result = ConvertFrom-Json $JSON
        $Result = UnrollArray $Result

        Return $Result

    }
    finally {

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
        [Parameter(Position=1, Mandatory=$true)]
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

##############################################################################
# Exports all functions that have standard Verb-* naming conventions.
# By convention, private functions used in this module are prefixed with a
# percent sign (%) which prevents them from being included below.
##############################################################################

Get-Verb | 
ForEach-Object { 
    Export-ModuleMember "$($_.Verb)-*" 
}
