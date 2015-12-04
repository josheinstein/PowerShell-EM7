# PowerShell-EM7
PowerShell cmdlets that wrap the ScienceLogic EM7 REST API.

## Usage

    Import-Module ScienceLogic   # Load the module
    Connect-EM7                  # Prompts for login/pass
    Get-EM7Device -Limit 10      # Gets 10 devices in the system

***

## Connect-EM7
### SYNOPSIS
Stores the credentials for accessing the ScienceLogic EM7 API in-memory
and tests the connection to the web service.

### SYNTAX
    Connect-EM7 [<CommonParameters>]

***

## Find-EM7Object
### SYNOPSIS
Queries the specified resource index for resources matching an optional
filter specification.

### SYNTAX
    Find-EM7Object [-Resource] <String> [-Filter <Hashtable>] [-Limit <Int32>] 
                   [-Offset <Int32>] [-ExpandProperty <String[]>]
                   [<CommonParameters>]

### PARAMETERS
#### -Resource <string>
The name of the resource index to query.
See the documentation for value values.
Examples include, device, device_group, organization, account...

#### -Filter <hashtable>
If specifieed, the keys of this hashtable are prefixed with
'filter.' and used as filters. For example: @{organization=6}

#### -Limit <int32>
Limits the results to the specified number. The default is 1000.

#### -Offset <int32>
The starting offset in the results to return.
If retrieving objects in pages of 100, you would specify 0 for page 1,
100 for page 2, 200 for page 3, and so on.

#### -ExpandProperty <string[]>
Specifies one or more property names that ordinarily contain a link
to a related object to automatically retrieve and place in the
returned object.

***

## Get-EM7Object
### SYNOPSIS
Retrieves a specific EM7 object by its ID.

### SYNTAX
    Get-EM7Object [-Resource] <String> [-ID] <Int32> [-ExpandProperty <String[]>]
                  [<CommonParameters>]

### PARAMETERS
#### -Resource <string>
The name of the resource index to query.
See the documentation for value values.
Examples include, device, device_group, organization, account...

#### -ID <int32>
The ID of a specific entity to retrieve.

#### -ExpandProperty <string[]>
Specifies one or more property names that ordinarily contain a link
to a related object to automatically retrieve and place in the
returned object.

***

## Get-EM7Device
### SYNOPSIS
Get a ScienceLogic EM7 device entity.
### SYNTAX
    Get-EM7Device [-Filter <Hashtable>] [-Limit <Int32>] [-Offset <Int32>]
                  [-ExpandProperty <String[]>] [<CommonParameters>]
    
    Get-EM7Device [-ID] <Int32> [-Limit <Int32>] [-Offset <Int32>] 
                  [-ExpandProperty <String[]>] [<CommonParameters>]

### PARAMETERS
#### -ID <int32>
If specified, retrieves the device with the specified ID

#### -Filter <hashtable>
If specifieed, the keys of this hashtable are prefixed with
'filter.' and used as filters. For example: @{organization=6}

#### -Limit <int32>
Limits the results to the specified number. The default is 1000.

#### -Offset <int32>
The starting offset in the results to return.
If retrieving objects in pages of 100, you would specify 0 for page 1,
100 for page 2, 200 for page 3, and so on.

#### -ExpandProperty <string[]>
Specifies one or more property names that ordinarily contain a link
to a related object to automatically retrieve and place in the
returned object.

***

## Get-EM7Organization
### SYNOPSIS
Get a ScienceLogic EM7 organization entity.

### SYNTAX
    Get-EM7Organization [-Filter <hashtable>] [-Limit <int32>] [-Offset <int32>]
                        [-ExpandProperty <string[]>] [<commonparameters>]
    
    Get-EM7Organization [-ID] <Int32> [-Limit <Int32>] [-Offset <Int32>] 
                        [-ExpandProperty <String[]>] [<CommonParameters>]

### PARAMETERS
#### -ID <int32>
If specified, retrieves the organization with the specified ID

#### -Filter <Hashtable>
If specifieed, the keys of this hashtable are prefixed with
'filter.' and used as filters. For example: @{state='PA'}

#### -Limit <Int32>
Limits the results to the specified number. The default is 1000.

#### -Offset <Int32>
The starting offset in the results to return.
If retrieving objects in pages of 100, you would specify 0 for page 1,
100 for page 2, 200 for page 3, and so on.

#### -ExpandProperty <String[]>
Specifies one or more property names that ordinarily contain a link
to a related object to automatically retrieve and place in the
returned object.
