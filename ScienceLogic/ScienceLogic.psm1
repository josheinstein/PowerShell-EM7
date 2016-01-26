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
    FormatResponse  = $false
    HideFilterInfo  = 0
    DefaultLimit    = 100
	DefaultPageSize = 500
    CredentialPath  = "${ENV:TEMP}\slcred.xml"
}

if (Test-Path $Globals.CredentialPath) {
    $Globals.Credentials = Import-Clixml $Globals.CredentialPath -ErrorAction 0
    $Globals.ApiRoot = $Globals.Credentials.URI
	$Globals.FormatResponse = $Globals.Credentials.FormatResponse
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

	EnsureConnected -ErrorAction Stop

	$FindArgs = @{
		Resource = $Resource
		ExpandProperty = $ExpandProperty
		Filter = @{}
		Limit = $Globals.DefaultLimit
	}

	if ($ID) {
		$FindArgs.Filter['_id.in'] = $ID -join ','
	}

	Find-EM7Object @FindArgs

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

	EnsureConnected -ErrorAction Stop

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

	while ($OutputCount -lt $Limit) {

		$URI = CreateUri @UriArgs
		$Result = @(HttpInvoke $URI | UnrollArray)
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

	}

}

##############################################################################
#.SYNOPSIS
# Updates the properties of a EM7 object at the specified URI. Only the
# properties specified in the -InputObject parameter will be updated.
##############################################################################
function Set-EM7Object {
	
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

##############################################################################
#.SYNOPSIS
# Get a ScienceLogic EM7 device entity.
##############################################################################
function Get-EM7Device {
    
    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the device with the specified ID
        [Parameter(ParameterSetName='ID', Position=1, Mandatory=$true)]
        [Int32[]]$ID,

        # If specified, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{organization=6}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

        # If specified, devices in the given organization are searched.
        [Alias('__OrganizationID')]
		[Parameter(ParameterSetName='Advanced', ValueFromPipelineByPropertyName=$true)]
        [Int32[]]$Organization,

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
        [String[]]$ExpandProperty = ('class_type/device_category','organization')

    )

	process {

		if ($Filter -eq $Null) { $Filter = @{} }

		if ($Organization.Length) {
			$Filter['organization.in'] = $Organization -join ','
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

##############################################################################
#.SYNOPSIS
# Get a ScienceLogic EM7 organization entity.
##############################################################################
function Get-EM7Organization {
    
    [CmdletBinding(DefaultParameterSetName='Advanced')]
    param(

        # If specified, retrieves the organization with the specified ID
        [Parameter(ParameterSetName='ID', Position=1, Mandatory=$true)]
        [Int32[]]$ID,

        # If specifieed, the keys of this hashtable are prefixed with
        # 'filter.' and used as filters. For example: @{state='PA'}
        [Parameter(ParameterSetName='Advanced')]
        [Hashtable]$Filter,

		# If specified, organizations are searched based on the company name
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

	if ($Filter -eq $Null) { $Filter = @{} }

	if ($Name) {
		$Operator = ''
		if ($Name.StartsWith('*') -and $Name.EndsWith('*')) { $Operator = '.contains' }
		elseif ($Name.StartsWith('*')) { $Operator = '.ends_with' }
		elseif ($Name.EndsWith('*')) { $Operator = '.begins_with' }
		$Filter["company$Operator"] = $Name.Trim('*')
	}

	switch ($PSCmdlet.ParameterSetName) {
		'ID' {
			Get-EM7Object organization -ID:$ID -ExpandProperty:$ExpandProperty
		}
		'Advanced' {
			Find-EM7Object organization -Filter:$Filter -Limit:$Limit -Offset:$Offset -OrderBy:$OrderBy -ExpandProperty:$ExpandProperty
		}
	}

}

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

		$Changes = @()
		$DeviceGroup = $Null

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
		elseif ($DeviceGroup.Count -gt 1) {
			
			# They specified a device group name and more than one matched

			$DeviceGroup = $Null
			Write-Error "More than one matching device group."
			Return

		}
		else {

			# Okay, we have exactly one device group.
			# Make sure the devices property is initialized.

			if (!$DeviceGroup.devices) {
				$DeviceGroup.devices = @()
			}

			Write-Verbose "Device Group: $($DeviceGroup.Name) ($($DeviceGroup.__URI))"
			Write-Verbose "Initial Devices: $(($DeviceGroup.devices | Split-Path -Leaf) -join ', ')"

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
					Write-Host "Device Group $($DeviceGroup.__URI) already contains $DID"
				}
				else {

					# If -WhatIf was supplied, ShouldProcess returns false and no change will
					# be made to the device group.

					if ($PSCmdlet.ShouldProcess($DeviceGroup.__URI, "Add Device $DID")) {
						
						Write-Verbose "Adding $DID"
						
						$Changes += $D
						$DeviceGroup.devices += $DID

					}

				}

			}

		}

	}

	end {

		# Changes are collected throughout the pipeline invocation and
		# only pushed up to the server at the end.
		# Double check we have a device group and changes were actually made.
		# Only push the devices property, rather than the entire object.

		if ($DeviceGroup -and $Changes.Count) {

			Set-EM7Object -URI $DeviceGroup.__URI @{devices=$DeviceGroup.devices}

			Write-Output $Changes

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
        [Parameter(Position=1, ValueFromPipeline=$true)]
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
                $Cache[$U] = HttpInvoke (%New-Uri $U -BaseUri $Globals.ApiRoot -QueryString @{extended_fetch=1}) | UnrollArray
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
        [Parameter(Position=1, Mandatory=$true)]
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
