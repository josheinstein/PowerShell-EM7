# PowerShell-EM7
PowerShell cmdlets that wrap the ScienceLogic EM7 REST API.

## Usage

    Import-Module ScienceLogic   # Load the module
    Connect-EM7                  # Prompts for login/pass
    Get-EM7Device -Limit 10      # Gets 10 devices in the system

***

## Connect-EM7 
Stores the credentials for accessing the ScienceLogic EM7 API in-memory
and tests the connection to the web service. 

### Syntax 

    Connect-EM7 [-URI] <Uri> [<CommonParameters>] 

### Outputs 
System.Management.Automation.PSObject 

*** 

## Find-EM7Object 
Queries the specified resource index for resources matching an optional
filter specification. 

### Syntax 

    Find-EM7Object [-Resource] <String> [-Filter <Hashtable>] [-Limit <Int32>]  
                   [-Offset <Int32>] [-ExpandProperty <String[]>] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*Resource* | X | 2 | The name of the resource index to query. See the documentation for value values. Examples include, device, device_group, organization, account... 
*Filter* |  |  | If specifieed, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{organization=6} 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Get-EM7Object 
Retrieves a specific EM7 object by its ID. 

### Syntax 

    Get-EM7Object [-Resource] <String> [-ID] <Int32> [-ExpandProperty <String[]>]  
                  [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*Resource* | X | 2 | The name of the resource index to query. See the documentation for value values. Examples include, device, device_group, organization, account... 
*ID* | X | 3 | The ID of a specific entity to retrieve. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Get-EM7Device 
Get a ScienceLogic EM7 device entity. 

### Syntax 

    Get-EM7Device [-Filter <Hashtable>] [-Limit <Int32>] [-Offset <Int32>]  
                  [-ExpandProperty <String[]>] [<CommonParameters>] 

    Get-EM7Device [-ID] <Int32> [-Limit <Int32>] [-Offset <Int32>] [-ExpandProperty  
                  <String[]>] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*ID* | X | 2 | If specified, retrieves the device with the specified ID 
*Filter* |  |  | If specifieed, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{organization=6} 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Get-EM7Organization 
Get a ScienceLogic EM7 organization entity. 

### Syntax 

    Get-EM7Organization [-Filter <Hashtable>] [-Limit <Int32>] [-Offset <Int32>]  
                        [-ExpandProperty <String[]>] [<CommonParameters>] 

    Get-EM7Organization [-ID] <Int32> [-Limit <Int32>] [-Offset <Int32>]  
                        [-ExpandProperty <String[]>] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*ID* | X | 2 | If specified, retrieves the organization with the specified ID 
*Filter* |  |  | If specifieed, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{state=&#39;PA&#39;} 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

