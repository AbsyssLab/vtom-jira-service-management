#Requires -Version 7.0

<#
.SYNOPSIS
    Interactive Configuration Setup for VTOM Jira Service Management Integration

.DESCRIPTION
    This script helps you configure the integration by automatically discovering
    available options in your Jira instance and generating the config.ps1 file.

.EXAMPLE
    .\setup_config.ps1
#>

# Configuration storage
$script:Config = @{}
$script:JiraBaseUrl = $null
$script:JiraAuthToken = $null

# Helper Functions
function Write-Header {
    param([string]$Text)
    
    Write-Host "`n$('='*70)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$('='*70)" -ForegroundColor Cyan
}

function Write-Step {
    param(
        [int]$Step,
        [string]$Text
    )
    
    Write-Host "`n[Step $Step] $Text" -ForegroundColor Yellow
    Write-Host "$('-'*70)" -ForegroundColor Yellow
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = $null
    )
    
    if ($Default) {
        $input = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $Default
        }
        return $input
    }
    
    return Read-Host $Prompt
}

function Get-UserChoice {
    param(
        [string]$Prompt,
        [array]$Options,
        [bool]$AllowNone = $false
    )
    
    Write-Host "`n$Prompt" -ForegroundColor White
    
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        Write-Host "  $($i + 1). $($option.Name) (ID: $($option.Id))" -ForegroundColor Gray
    }
    
    if ($AllowNone) {
        Write-Host "  0. None / Skip" -ForegroundColor Gray
    }
    
    while ($true) {
        $choice = Read-Host "`nEnter your choice (number)"
        
        try {
            $choiceNum = [int]$choice
            
            if ($AllowNone -and $choiceNum -eq 0) {
                return $null
            }
            
            if ($choiceNum -ge 1 -and $choiceNum -le $Options.Count) {
                $selected = $Options[$choiceNum - 1]
                Write-Host "Selected: $($selected.Name)" -ForegroundColor Green
                return $selected.Id
            }
            else {
                $range = if ($AllowNone) { "0" } else { "1" }
                Write-Host "Invalid choice. Please enter a number between $range and $($Options.Count)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
        }
    }
}

function Invoke-JiraApi {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Body = $null
    )
    
    $headers = @{
        "Authorization" = "Basic $script:JiraAuthToken"
        "Content-Type" = "application/json"
        "Accept" = "application/json"
    }
    
    try {
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Body $jsonBody
        }
        else {
            $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers
        }
        return $response
    }
    catch {
        Write-Host "API call failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Test-JiraConnection {
    Write-Host "`nTesting connection..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-JiraApi -Uri "$script:JiraBaseUrl/rest/api/3/myself"
        if ($response) {
            Write-Host "OK Successfully connected as: $($response.displayName)" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "X Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $false
}

function Get-JiraProjects {
    try {
        $response = Invoke-JiraApi -Uri "$script:JiraBaseUrl/rest/api/3/project"
        if ($response) {
            return $response | ForEach-Object {
                @{
                    Id = $_.key
                    Name = "$($_.name) ($($_.key))"
                }
            }
        }
    }
    catch {
        Write-Host "Error fetching projects: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @()
}

function Get-JiraIssueTypes {
    param([string]$ProjectKey)
    
    try {
        $response = Invoke-JiraApi -Uri "$script:JiraBaseUrl/rest/api/3/project/$ProjectKey"
        if ($response) {
            return $response.issueTypes | ForEach-Object {
                @{
                    Id = $_.name
                    Name = $_.name
                }
            }
        }
    }
    catch {
        Write-Host "Error fetching issue types: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @()
}

function Get-JiraPriorities {
    try {
        $response = Invoke-JiraApi -Uri "$script:JiraBaseUrl/rest/api/3/priority"
        if ($response) {
            return $response | ForEach-Object {
                @{
                    Id = $_.name
                    Name = $_.name
                }
            }
        }
    }
    catch {
        Write-Host "Error fetching priorities: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @()
}

function Get-JiraCustomFields {
    param(
        [string]$ProjectKey,
        [string]$IssueType
    )
    
    try {
        $uri = "$script:JiraBaseUrl/rest/api/3/issue/createmeta?projectKeys=$ProjectKey&expand=projects.issuetypes.fields"
        $response = Invoke-JiraApi -Uri $uri
        
        $customFields = @{}
        
        if ($response) {
            foreach ($project in $response.projects) {
                foreach ($it in $project.issuetypes) {
                    if ($it.name -eq $IssueType) {
                        foreach ($field in $it.fields.PSObject.Properties) {
                            if ($field.Name -like "customfield_*") {
                                $customFields[$field.Name] = $field.Value.name
                            }
                        }
                    }
                }
            }
        }
        
        return $customFields
    }
    catch {
        Write-Host "Error fetching custom fields: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @{}
}

function Get-JiraRequestTypes {
    try {
        $response = Invoke-JiraApi -Uri "$script:JiraBaseUrl/rest/servicedeskapi/servicedesk"
        
        $requestTypes = @()
        
        if ($response) {
            foreach ($sd in $response.values) {
                $sdId = $sd.id
                if ($sdId) {
                    $rtResponse = Invoke-JiraApi -Uri "$script:JiraBaseUrl/rest/servicedeskapi/servicedesk/$sdId/requesttype"
                    if ($rtResponse) {
                        foreach ($rt in $rtResponse.values) {
                            $requestTypes += @{
                                Id = [string]$rt.id
                                Name = "$($rt.name) (Service Desk: $($sd.projectName))"
                            }
                        }
                    }
                }
            }
        }
        
        return $requestTypes
    }
    catch {
        Write-Host "Error fetching request types: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @()
}

function Find-CustomFieldByName {
    param(
        [hashtable]$CustomFields,
        [string[]]$SearchTerms
    )
    
    foreach ($fieldId in $CustomFields.Keys) {
        $fieldName = $CustomFields[$fieldId].ToLower()
        foreach ($term in $SearchTerms) {
            if ($fieldName -like "*$($term.ToLower())*") {
                return $fieldId
            }
        }
    }
    
    return $null
}

function Setup-Connection {
    Write-Step -Step 1 -Text "Connection Setup"
    
    Write-Host "`nTo connect to Jira, you need:" -ForegroundColor White
    Write-Host "  1. Your Jira instance URL (e.g., https://your-domain.atlassian.net)" -ForegroundColor Gray
    Write-Host "  2. An API token (create one at: https://id.atlassian.com/manage-profile/security/api-tokens)" -ForegroundColor Gray
    
    $script:JiraBaseUrl = (Get-UserInput -Prompt "`nEnter your Jira instance URL").TrimEnd('/')
    
    Write-Host "`nFor the API token, you need to provide: email:api_token encoded in base64" -ForegroundColor White
    Write-Host "Example: [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('your-email@domain.com:your-api-token'))" -ForegroundColor Gray
    
    $useManual = Get-UserInput -Prompt "`nDo you want to enter base64 token manually? (y/n)" -Default "n"
    
    if ($useManual -eq 'y') {
        $script:JiraAuthToken = Get-UserInput -Prompt "Enter your base64 encoded token"
    }
    else {
        $email = Get-UserInput -Prompt "Enter your Jira email"
        $apiToken = Get-UserInput -Prompt "Enter your API token"
        $credentials = "$email`:$apiToken"
        $script:JiraAuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($credentials))
    }
    
    if (-not (Test-JiraConnection)) {
        Write-Host "`nX Failed to connect to Jira. Please check your credentials." -ForegroundColor Red
        exit 1
    }
    
    $script:Config['jiraBaseUrl'] = $script:JiraBaseUrl
    $script:Config['jiraAuthToken'] = $script:JiraAuthToken
}

function Setup-Project {
    Write-Step -Step 2 -Text "Project Selection"
    
    Write-Host "`nFetching available projects..." -ForegroundColor Cyan
    $projects = Get-JiraProjects
    
    if ($projects.Count -eq 0) {
        Write-Host "No projects found or unable to fetch projects." -ForegroundColor Red
        exit 1
    }
    
    $projectKey = Get-UserChoice -Prompt "Select your project:" -Options $projects
    $script:Config['defaultProjectKey'] = $projectKey
    
    Write-Host "`nOK Project selected: $projectKey" -ForegroundColor Green
}

function Setup-IssueType {
    Write-Step -Step 3 -Text "Issue Type Selection"
    
    Write-Host "`nFetching available issue types..." -ForegroundColor Cyan
    $issueTypes = Get-JiraIssueTypes -ProjectKey $script:Config['defaultProjectKey']
    
    if ($issueTypes.Count -eq 0) {
        Write-Host "No issue types found." -ForegroundColor Yellow
        $script:Config['defaultIssueType'] = "Incident"
        return
    }
    
    $issueType = Get-UserChoice -Prompt "Select the default issue type for VTOM alarms:" -Options $issueTypes
    $script:Config['defaultIssueType'] = $issueType
    
    Write-Host "`nOK Issue type selected: $issueType" -ForegroundColor Green
}

function Setup-Priority {
    Write-Step -Step 4 -Text "Priority Selection"
    
    Write-Host "`nFetching available priorities..." -ForegroundColor Cyan
    $priorities = Get-JiraPriorities
    
    if ($priorities.Count -eq 0) {
        Write-Host "No priorities found." -ForegroundColor Yellow
        $script:Config['defaultPriority'] = "High"
        return
    }
    
    $priority = Get-UserChoice -Prompt "Select the default priority for VTOM alarms:" -Options $priorities
    $script:Config['defaultPriority'] = $priority
    
    Write-Host "`nOK Priority selected: $priority" -ForegroundColor Green
}

function Setup-CustomFields {
    Write-Step -Step 5 -Text "Custom Fields Configuration"
    
    Write-Host "`nFetching custom fields..." -ForegroundColor Cyan
    $customFields = Get-JiraCustomFields -ProjectKey $script:Config['defaultProjectKey'] -IssueType $script:Config['defaultIssueType']
    
    if ($customFields.Count -eq 0) {
        Write-Host "No custom fields found." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nFound $($customFields.Count) custom fields" -ForegroundColor Green
    
    # VTOM Object Name field
    Write-Host "`n--- VTOM Object Name Field ---" -ForegroundColor Cyan
    Write-Host "This field is used to track VTOM objects and detect duplicate issues." -ForegroundColor Gray
    
    $vtomField = Find-CustomFieldByName -CustomFields $customFields -SearchTerms @('vtom', 'object', 'name')
    if ($vtomField) {
        Write-Host "Suggested field: $($customFields[$vtomField]) ($vtomField)" -ForegroundColor Yellow
        $useSuggested = Get-UserInput -Prompt "Use this field? (y/n)" -Default "y"
        if ($useSuggested -ne 'y') {
            $vtomField = $null
        }
    }
    
    if (-not $vtomField) {
        $fieldOptions = $customFields.GetEnumerator() | ForEach-Object {
            @{
                Id = $_.Key
                Name = "$($_.Value) ($($_.Key))"
            }
        }
        $vtomField = Get-UserChoice -Prompt "Select the field for VTOM object name:" -Options $fieldOptions -AllowNone $true
    }
    
    $script:Config['vtomObjectNameField'] = $vtomField
    
    # Request Type field
    Write-Host "`n--- Request Type Field (Jira Service Management) ---" -ForegroundColor Cyan
    Write-Host "This field is required for JSM to categorize incidents." -ForegroundColor Gray
    
    $requestTypeField = Find-CustomFieldByName -CustomFields $customFields -SearchTerms @('request', 'type')
    if ($requestTypeField) {
        Write-Host "Found Request Type field: $requestTypeField" -ForegroundColor Green
        $script:Config['requestTypeField'] = $requestTypeField
    }
    else {
        Write-Host "Request Type field not found. You may need to configure it manually." -ForegroundColor Yellow
        $script:Config['requestTypeField'] = $null
    }
    
    # Affected Services field
    Write-Host "`n--- Affected Services Field (Optional) ---" -ForegroundColor Cyan
    $servicesField = Find-CustomFieldByName -CustomFields $customFields -SearchTerms @('affected', 'service', 'services')
    if ($servicesField) {
        Write-Host "Found Affected Services field: $servicesField" -ForegroundColor Green
        $script:Config['affectedServicesField'] = $servicesField
    }
    else {
        $script:Config['affectedServicesField'] = $null
    }
    
    # Organizations field
    Write-Host "`n--- Organizations Field (Optional) ---" -ForegroundColor Cyan
    $orgsField = Find-CustomFieldByName -CustomFields $customFields -SearchTerms @('organization', 'organisations')
    if ($orgsField) {
        Write-Host "Found Organizations field: $orgsField" -ForegroundColor Green
        $script:Config['organizationsField'] = $orgsField
    }
    else {
        $script:Config['organizationsField'] = $null
    }
}

function Setup-RequestType {
    Write-Step -Step 6 -Text "Request Type Selection (JSM)"
    
    if (-not $script:Config['requestTypeField']) {
        Write-Host "Request Type field not configured. Skipping..." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nFetching available request types..." -ForegroundColor Cyan
    $requestTypes = Get-JiraRequestTypes
    
    if ($requestTypes.Count -eq 0) {
        Write-Host "No request types found or Service Desk API not available." -ForegroundColor Yellow
        Write-Host "You may need to configure the Request Type ID manually." -ForegroundColor Yellow
        return
    }
    
    $rtId = Get-UserChoice -Prompt "Select the default request type for VTOM incidents:" -Options $requestTypes
    $script:Config['defaultRequestTypeId'] = $rtId
    
    Write-Host "`nOK Request type selected: ID $rtId" -ForegroundColor Green
}

function Generate-ConfigFile {
    Write-Step -Step 7 -Text "Generate Configuration File"
    
    $configContent = @"
# Jira Service Management Configuration
# Generated by setup_config.ps1

# Jira instance configuration
`$jiraBaseUrl = "$($script:Config['jiraBaseUrl'])"
`$jiraAuthToken = "$($script:Config['jiraAuthToken'])"

# Default values for issue creation
`$defaultProjectKey = "$($script:Config['defaultProjectKey'])"
`$defaultIssueType = "$($script:Config['defaultIssueType'])"
`$defaultPriority = "$($script:Config['defaultPriority'])"
`$defaultAssignee = `$null  # Set to email/username if you want to auto-assign

# Custom field mappings (required for Jira Service Management)
`$customFieldMappings = @{
    "vtom_object_name" = "$($script:Config['vtomObjectNameField'])"
    "request_type" = "$($script:Config['requestTypeField'])"
    "affected_services" = "$($script:Config['affectedServicesField'])"
    "organizations" = "$($script:Config['organizationsField'])"
}

# Default values for JSM fields
`$jsmDefaultValues = @{
    "request_type" = "$($script:Config['defaultRequestTypeId'])"
    "affected_services" = @()
    "organizations" = @()
}

# Priority mapping from Visual TOM severity to Jira priority
`$priorityMapping = @{
    "critical" = "Highest"
    "high" = "High"
    "medium" = "Medium"
    "low" = "Low"
    "info" = "Lowest"
}

# Issue type mapping from Visual TOM alarm type to Jira issue type
`$issueTypeMapping = @{
    "job_failure" = "Incident"
    "system_alert" = "Incident"
    "performance" = "Task"
    "maintenance" = "Task"
}
"@
    
    Write-Host "`nConfiguration file content:" -ForegroundColor White
    Write-Host "$('-'*70)" -ForegroundColor Gray
    Write-Host $configContent -ForegroundColor Gray
    Write-Host "$('-'*70)" -ForegroundColor Gray
    
    $save = Get-UserInput -Prompt "`nSave this configuration to config.ps1? (y/n)" -Default "y"
    
    if ($save -eq 'y') {
        $configContent | Out-File -FilePath "config.ps1" -Encoding UTF8
        Write-Host "`nOK Configuration saved to config.ps1" -ForegroundColor Green
        Write-Host "`nYou can now use the integration scripts:" -ForegroundColor White
        Write-Host "  - Jira_CreateTicket.py (Python)" -ForegroundColor Gray
        Write-Host "  - Jira_CreateTicket.ps1 (PowerShell)" -ForegroundColor Gray
    }
    else {
        Write-Host "`nConfiguration not saved. You can copy the content above manually." -ForegroundColor Yellow
    }
}

# Main execution
try {
    Write-Header "VTOM Jira Service Management - Configuration Setup"
    Write-Host "`nThis wizard will help you configure the integration with your Jira instance." -ForegroundColor White
    Write-Host "You will be asked to select options from your Jira configuration." -ForegroundColor White
    
    Setup-Connection
    Setup-Project
    Setup-IssueType
    Setup-Priority
    Setup-CustomFields
    Setup-RequestType
    Generate-ConfigFile
    
    Write-Header "Setup Complete!"
    Write-Host "`nOK Configuration setup completed successfully!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor White
    Write-Host "  1. Review the generated config.ps1 file" -ForegroundColor Gray
    Write-Host "  2. Test the integration with a sample alarm" -ForegroundColor Gray
    Write-Host "  3. Configure VTOM to use the scripts" -ForegroundColor Gray
}
catch {
    Write-Host "`n`nError during setup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

