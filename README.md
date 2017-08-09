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

    Connect-EM7 [-URI] <Uri> [-Formatted] [-IgnoreSSLErrors] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*URI* | X | 2 | The API root URI 
*Formatted* |  |  | Specify this when you&#39;ll be using a HTTP debugger like Fiddler. It will cause the JSON to be formatted with whitespace for easier reading, but is more likely to result in errors with larger responses. 
*IgnoreSSLErrors* |  |  | If specified, SSL errors will be ignored in all SSL requests made from this PowerShell session. This is an awful hacky way of doing this and it should only be used for testing. 

*** 

## Add-EM7DeviceGroupMember 
Adds a device as a static member of the specified device group. 

### Syntax 

    Add-EM7DeviceGroupMember [-Name] <String> [-Device <PSObject[]>] [-WhatIf]  
                             [-Confirm] [<CommonParameters>] 

    Add-EM7DeviceGroupMember -ID <Int32> [-Device <PSObject[]>] [-WhatIf]  
                             [-Confirm] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*Name* | X | 2 | The name of an existing device group. This must match one and only one device group, otherwise use ID. 
*ID* | X |  | The ID of an existing device group. 
*Device* |  |  | A device piped from the output of another command (such as Get-EM7Device). This property must be a device and have a corresponding device URI. 
*WhatIf* |  |  |  
*Confirm* |  |  |  

*** 

## Find-EM7Object 
Queries the specified resource index for resources matching an optional
filter specification. 

### Syntax 

    Find-EM7Object [-Resource] <String> [-Filter <Hashtable>] [-Limit <Int32>]  
                   [-Offset <Int32>] [-OrderBy <String>] [-ExpandProperty <String[]>]  
                   [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*Resource* | X | 2 | The name of the resource index to query. See the documentation for value values. Examples include, device, device_group, organization, account... 
*Filter* |  |  | If specifieed, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{organization=6} 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*OrderBy* |  |  | Optionally sorts the results by this field in ascending order, or if the field is prefixed with a dash (-) in descending order. You can also pipe the output to PowerShell&#39;s Sort-Object cmdlet, but this parameter is processed on the server, which will affect how results are paginated when there are more results than fit in a single page. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Get-EM7Device 
Get a ScienceLogic EM7 device entity. 

### Syntax 

    Get-EM7Device [-Filter <Hashtable>] [-Organization <Int32[]>] [-IP <String>]  
                  [-Limit <Int32>] [-Offset <Int32>] [-OrderBy <String>] [-ExpandProperty  
                  <String[]>] [<CommonParameters>] 

    Get-EM7Device [-ID] <Int32[]> [-ExpandProperty <String[]>] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*ID* | X | 2 | If specified, retrieves the device with the specified ID 
*Filter* |  |  | If specified, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{organization=6} 
*Organization* |  |  | If specified, devices in the given organization are searched. 
*IP* |  |  | If specified, devices with the given IP address are searched. Wildcards are allowed. 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*OrderBy* |  |  | Optionally sorts the results by this field in ascending order, or if the field is prefixed with a dash (-) in descending order. You can also pipe the output to PowerShell&#39;s Sort-Object cmdlet, but this parameter is processed on the server, which will affect how results are paginated when there are more results than fit in a single page. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Get-EM7DeviceGroup 

Get-EM7DeviceGroup [-Filter &lt;hashtable&gt;] [-Name &lt;string&gt;] [-Limit &lt;int&gt;] [-Offset &lt;int&gt;] [-OrderBy &lt;string&gt;] [-ExpandProperty &lt;string[]&gt;] [&lt;CommonParameters&gt;]

Get-EM7DeviceGroup [-ID] &lt;int[]&gt; [-Limit &lt;int&gt;] [-Offset &lt;int&gt;] [-OrderBy &lt;string&gt;] [-ExpandProperty &lt;string[]&gt;] [&lt;CommonParameters&gt;]
 

### Syntax 
                       syntaxItem                                                                       
                       ----------                                                                       
                       {@{name=Get-EM7DeviceGroup; CommonParameters=True; WorkflowCommonParameters=F... 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*ExpandProperty* |  |  |  
*Filter* |  |  |  
*ID* | X | 1 |  
*Limit* |  |  |  
*Name* |  |  |  
*Offset* |  |  |  
*OrderBy* |  |  |  

### Inputs 
None
 

### Outputs 
System.Object 

*** 

## Get-EM7DeviceGroupMember 
Gets a list of devices that are members of the specified device group. 

### Syntax 

    Get-EM7DeviceGroupMember [-Filter <Hashtable>] [-Name <String>] [-Limit  
                             <Int32>] [-Offset <Int32>] [-OrderBy <String>] [-ExpandProperty <String[]>]  
                             [-Recurse] [<CommonParameters>] 

    Get-EM7DeviceGroupMember [-ID] <Int32[]> [-Limit <Int32>] [-Offset <Int32>]  
                             [-OrderBy <String>] [-ExpandProperty <String[]>] [-Recurse] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*ID* | X | 2 | If specified, retrieves the device group with the specified ID 
*Filter* |  |  | If specifieed, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{state=&#39;PA&#39;} 
*Name* |  |  | If specified, device groups are searched based on the name Wildcards can be used at either end of the name to check for partial matches. 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*OrderBy* |  |  | Optionally sorts the results by this field in ascending order, or if the field is prefixed with a dash (-) in descending order. You can also pipe the output to PowerShell&#39;s Sort-Object cmdlet, but this parameter is processed on the server, which will affect how results are paginated when there are more results than fit in a single page. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 
*Recurse* |  |  | If specified, device groups that are members of this device group will be recursively expanded as well. 

*** 

## Get-EM7Object 
Retrieves a specific EM7 object by its ID. 

### Syntax 

    Get-EM7Object [-Resource] <String> [-ID] <Int32[]> [-ExpandProperty <String[]>]  
                  [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*Resource* | X | 2 | The name of the resource index to query. See the documentation for value values. Examples include, device, device_group, organization, account... 
*ID* | X | 3 | The ID of a specific entity to retrieve. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Get-EM7Organization 
Get a ScienceLogic EM7 organization entity. 

### Syntax 

    Get-EM7Organization [-Filter <Hashtable>] [-Company <String>] [-BillingID  
                        <String[]>] [-CrmID <String[]>] [-Limit <Int32>] [-Offset <Int32>] [-OrderBy  
                        <String>] [-ExpandProperty <String[]>] [<CommonParameters>] 

    Get-EM7Organization [-ID] <Int32[]> [-Limit <Int32>] [-Offset <Int32>]  
                        [-OrderBy <String>] [-ExpandProperty <String[]>] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*ID* | X | 2 | If specified, retrieves the organization with the specified ID 
*Filter* |  |  | If specifieed, the keys of this hashtable are prefixed with &#39;filter.&#39; and used as filters. For example: @{state=&#39;PA&#39;} 
*Company* |  |  | If specified, organizations are searched based on the company name Wildcards can be used at either end of the name to check for partial matches. 
*BillingID* |  |  | Searches for organizations with the specified billing_id. 
*CrmID* |  |  | Searches for organizations with the specified crm_id. 
*Limit* |  |  | Limits the results to the specified number. The default is 1000. 
*Offset* |  |  | The starting offset in the results to return. If retrieving objects in pages of 100, you would specify 0 for page 1, 100 for page 2, 200 for page 3, and so on. 
*OrderBy* |  |  | Optionally sorts the results by this field in ascending order, or if the field is prefixed with a dash (-) in descending order. You can also pipe the output to PowerShell&#39;s Sort-Object cmdlet, but this parameter is processed on the server, which will affect how results are paginated when there are more results than fit in a single page. 
*ExpandProperty* |  |  | Specifies one or more property names that ordinarily contain a link to a related object to automatically retrieve and place in the  returned object. 

*** 

## Set-EM7Object 
Updates the properties of a EM7 object at the specified URI. Only the
properties specified in the -InputObject parameter will be updated. 

### Syntax 

    Set-EM7Object [-URI <Uri>] [[-InputObject] <PSObject>] [-PassThru] [-WhatIf]  
                  [-Confirm] [<CommonParameters>] 

Parameter | Required | Pos  | Description 
--------- | :------: | ---: | ----------- 
*URI* |  |  | The relative or absolute URI of the resource, such as /api/organization/1 or https://servername/api/device/9. 
*InputObject* |  | 2 | A custom object (which may be a Hashtable or other PSObject such as a deserialized JSON object or PSCustomObject.) 
*PassThru* |  |  | If specified, the output of the update will be deserialized and written to the pipeline. 
*WhatIf* |  |  |  
*Confirm* |  |  |  

*** 

