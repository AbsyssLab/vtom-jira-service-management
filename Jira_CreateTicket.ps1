#Requires -Version 7.0

<#
.SYNOPSIS
    Jira Service Management Integration for Visual TOM
    Creates and manages Jira tickets from Visual TOM alarms.

.DESCRIPTION
    This script checks if a ticket already exists for the object name and is not closed.
    If it does, it will create a child ticket with the new information.
    If not, it will create a new ticket.
    If provided, the script will add the output and error logs as attachments to the ticket.

.PARAMETER ProjectKey
    Jira project key (required)

.PARAMETER Summary
    Issue summary (required)

.PARAMETER Description
    Issue description (required)

.PARAMETER ObjectName
    VTOM object name (required)

.PARAMETER IssueType
    Issue type (optional, defaults to config value)

.PARAMETER Priority
    Issue priority (optional, defaults to config value)

.PARAMETER Assignee
    Issue assignee email (optional)

.PARAMETER OutAttachmentName
    Output log attachment name (optional)

.PARAMETER OutAttachmentFile
    Output log attachment file path (optional)

.PARAMETER ErrorAttachmentName
    Error log attachment name (optional)

.PARAMETER ErrorAttachmentFile
    Error log attachment file path (optional)

.PARAMETER Severity
    VTOM alarm severity for priority mapping (optional)

.PARAMETER AlarmType
    VTOM alarm type for issue type mapping (optional)

.EXAMPLE
    .\Jira_CreateTicket.ps1 -ProjectKey "ABS" -Summary "Job failed" -Description "Job has failed" -ObjectName "MyJob" -Priority "High"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectKey,
    
    [Parameter(Mandatory = $true)]
    [string]$Summary,
    
    [Parameter(Mandatory = $true)]
    [string]$Description,
    
    [Parameter(Mandatory = $true)]
    [string]$ObjectName,
    
    [Parameter(Mandatory = $false)]
    [string]$IssueType = "Incident",
    
    [Parameter(Mandatory = $false)]
    [string]$Priority = "High",
    
    [Parameter(Mandatory = $false)]
    [string]$Assignee,
    
    [Parameter(Mandatory = $false)]
    [string]$OutAttachmentName,
    
    [Parameter(Mandatory = $false)]
    [string]$OutAttachmentFile,
    
    [Parameter(Mandatory = $false)]
    [string]$ErrorAttachmentName,
    
    [Parameter(Mandatory = $false)]
    [string]$ErrorAttachmentFile,
    
    [Parameter(Mandatory = $false)]
    [string]$Severity,
    
    [Parameter(Mandatory = $false)]
    [string]$AlarmType
)

# Load configuration
$configPath = Join-Path $PSScriptRoot "config.ps1"
if (Test-Path $configPath) {
    . $configPath
} else {
    Write-Error "Configuration file config.ps1 not found. Please copy config.template.ps1 to config.ps1 and configure it."
    exit 1
}

# Jira API functions
function Invoke-JiraApi {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Body = $null,
        [string]$ContentType = "application/json"
    )
    
    $headers = @{
        "Authorization" = "Basic $jiraAuthToken"
        "Content-Type" = $ContentType
        "Accept" = "application/json"
    }
    
    try {
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Body $jsonBody
        } else {
            $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers
        }
        return $response
    }
    catch {
        Write-Error "API call failed: $($_.Exception.Message)"
        return $null
    }
}

function Search-ExistingIssue {
    param(
        [string]$ObjectName,
        [string]$ProjectKey
    )
    
    # Get the custom field ID for vtom_object_name
    $vtomFieldId = $customFieldMappings["vtom_object_name"]
    if (-not $vtomFieldId) {
        Write-Warning "vtom_object_name custom field not configured, skipping existing issue search"
        return $null
    }
    
    # Use custom field for search instead of summary
    $jql = "project = `"$ProjectKey`" AND status NOT IN (Done, Closed, Resolved) AND `"$vtomFieldId`" ~ `"$ObjectName`""
    $uri = "$jiraBaseUrl/rest/api/3/search?jql=$([System.Web.HttpUtility]::UrlEncode($jql))&maxResults=1"
    
    $response = Invoke-JiraApi -Uri $uri
    if ($response -and $response.total -gt 0) {
        return $response.issues[0]
    }
    return $null
}

function New-JiraIssue {
    param(
        [string]$ProjectKey,
        [string]$IssueType,
        [string]$Summary,
        [string]$Description,
        [string]$Priority,
        [string]$Assignee,
        [hashtable]$CustomFields
    )
    
    $issueData = @{
        fields = @{
            project = @{ key = $ProjectKey }
            issuetype = @{ name = $IssueType }
            summary = $Summary
            description = @{
                type = "doc"
                version = 1
                content = @(
                    @{
                        type = "paragraph"
                        content = @(
                            @{
                                type = "text"
                                text = $Description
                            }
                        )
                    }
                )
            }
            priority = @{ name = $Priority }
        }
    }
    
    if ($Assignee) {
        $issueData.fields.assignee = @{ emailAddress = $Assignee }
    }
    
    if ($CustomFields) {
        foreach ($key in $CustomFields.Keys) {
            $issueData.fields[$key] = $CustomFields[$key]
        }
    }
    
    $uri = "$jiraBaseUrl/rest/api/3/issue"
    return Invoke-JiraApi -Uri $uri -Method "POST" -Body $issueData
}

function New-JiraSubtask {
    param(
        [string]$ParentKey,
        [string]$ProjectKey,
        [string]$IssueType,
        [string]$Summary,
        [string]$Description,
        [string]$Priority,
        [string]$Assignee,
        [hashtable]$CustomFields
    )
    
    $issueData = @{
        fields = @{
            project = @{ key = $ProjectKey }
            issuetype = @{ name = "Sub-task" }
            parent = @{ key = $ParentKey }
            summary = $Summary
            description = @{
                type = "doc"
                version = 1
                content = @(
                    @{
                        type = "paragraph"
                        content = @(
                            @{
                                type = "text"
                                text = $Description
                            }
                        )
                    }
                )
            }
            priority = @{ name = $Priority }
        }
    }
    
    if ($Assignee) {
        $issueData.fields.assignee = @{ emailAddress = $Assignee }
    }
    
    if ($CustomFields) {
        foreach ($key in $CustomFields.Keys) {
            $issueData.fields[$key] = $CustomFields[$key]
        }
    }
    
    $uri = "$jiraBaseUrl/rest/api/3/issue"
    return Invoke-JiraApi -Uri $uri -Method "POST" -Body $issueData
}

function Add-JiraAttachment {
    param(
        [string]$IssueKey,
        [string]$FilePath,
        [string]$FileName
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Attachment file $FilePath does not exist"
        return $false
    }
    
    try {
        $uri = "$jiraBaseUrl/rest/api/3/issue/$IssueKey/attachments"
        $headers = @{
            "Authorization" = "Basic $jiraAuthToken"
            "X-Atlassian-Token" = "no-check"
        }
        
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`"",
            "Content-Type: application/octet-stream$LF",
            [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileBytes),
            "--$boundary--$LF"
        ) -join $LF
        
        Invoke-RestMethod -Uri $uri -Method "POST" -Headers $headers -Body $bodyLines -ContentType "multipart/form-data; boundary=$boundary" | Out-Null
        return $true
    }
    catch {
        Write-Error "Error adding attachment: $($_.Exception.Message)"
        return $false
    }
}

function Add-JiraComment {
    param(
        [string]$IssueKey,
        [string]$Comment
    )
    
    $commentData = @{
        body = @{
            type = "doc"
            version = 1
            content = @(
                @{
                    type = "paragraph"
                    content = @(
                        @{
                            type = "text"
                            text = $Comment
                        }
                    )
                }
            )
        }
    }
    
    $uri = "$jiraBaseUrl/rest/api/3/issue/$IssueKey/comment"
    return Invoke-JiraApi -Uri $uri -Method "POST" -Body $commentData
}

# Main execution
try {
    # Map priority and issue type if mappings are provided
    if ($Severity -and $priorityMapping -and $priorityMapping.ContainsKey($Severity.ToLower())) {
        $Priority = $priorityMapping[$Severity.ToLower()]
    }
    
    if ($AlarmType -and $issueTypeMapping -and $issueTypeMapping.ContainsKey($AlarmType.ToLower())) {
        $IssueType = $issueTypeMapping[$AlarmType.ToLower()]
    }
    
    # Prepare custom fields
    $customFields = @{}
    if ($customFieldMappings) {
        # Map vtom_object_name to the correct custom field ID
        $vtomFieldId = $customFieldMappings["vtom_object_name"]
        if ($vtomFieldId) {
            $customFields[$vtomFieldId] = $ObjectName
        }
        
        # Map other custom fields if they exist
        foreach ($fieldName in $customFieldMappings.Keys) {
            if ($fieldName -eq "vtom_job_name") {
                $customFields[$customFieldMappings[$fieldName]] = $ObjectName
            }
        }
    }
    
    # Search for existing issue
    $existingIssue = Search-ExistingIssue -ObjectName $ObjectName -ProjectKey $ProjectKey
    
    if ($existingIssue) {
        Write-Host "Found existing issue: $($existingIssue.key)"
        
        # Create subtask
        $subtaskSummary = "New alarm: $Summary"
        $subtaskDescription = "New alarm detected for $ObjectName`n`n$Description"
        
        $result = New-JiraSubtask -ParentKey $existingIssue.key -ProjectKey $ProjectKey -IssueType $IssueType -Summary $subtaskSummary -Description $subtaskDescription -Priority $Priority -Assignee $Assignee -CustomFields $customFields
        
        if ($result) {
            Write-Host "Created subtask: $($result.key)"
            $issueKey = $result.key
        } else {
            Write-Error "Failed to create subtask"
            exit 1
        }
    } else {
        # Create new issue
        $result = New-JiraIssue -ProjectKey $ProjectKey -IssueType $IssueType -Summary $Summary -Description $Description -Priority $Priority -Assignee $Assignee -CustomFields $customFields
        
        if ($result) {
            Write-Host "Created new issue: $($result.key)"
            $issueKey = $result.key
        } else {
            Write-Error "Failed to create issue"
            exit 1
        }
    }
    
    # Add attachments if provided
    if ($OutAttachmentFile -and $OutAttachmentName) {
        if (Add-JiraAttachment -IssueKey $issueKey -FilePath $OutAttachmentFile -FileName $OutAttachmentName) {
            Write-Host "Added output log attachment: $OutAttachmentName"
        }
    }
    
    if ($ErrorAttachmentFile -and $ErrorAttachmentName) {
        if (Add-JiraAttachment -IssueKey $issueKey -FilePath $ErrorAttachmentFile -FileName $ErrorAttachmentName) {
            Write-Host "Added error log attachment: $ErrorAttachmentName"
        }
    }
    
    # Add comment with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $comment = "VTOM alarm processed at $timestamp"
    if (Add-JiraComment -IssueKey $issueKey -Comment $comment) {
        Write-Host "Added timestamp comment"
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
