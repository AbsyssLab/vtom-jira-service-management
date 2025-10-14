# Jira Service Management Configuration Template
# Copy this file to config.ps1 and update with your Jira instance details

# Jira instance configuration
$jiraBaseUrl = "https://your-domain.atlassian.net"  # Replace with your Jira instance URL
$jiraAuthToken = "YOUR_BASE64_ENCODED_EMAIL:API_TOKEN"  # Replace with your base64 encoded email:api_token

# Default values for issue creation
$defaultProjectKey = "PROJ"  # Replace with your Jira project key
$defaultIssueType = "[System] Incident"  # Use the exact name from your Jira project
$defaultPriority = "High"
$defaultAssignee = $null  # Set to email/username if you want to auto-assign

# Custom field mappings (required for Jira Service Management)
# Map VTOM variables to Jira custom fields
# To find custom field IDs, go to Jira Settings > Issues > Custom fields
$customFieldMappings = @{
    "vtom_object_name" = "customfield_10055"  # Replace with actual custom field ID for VTOM object tracking
    # Champs requis pour Jira Service Management
    "request_type" = "customfield_10010"  # Request Type - REQUIS pour JSM
    "affected_services" = "customfield_10043"  # Affected services (optional)
    "organizations" = "customfield_10002"  # Organizations (optional)
}

# Valeurs par défaut pour les champs JSM (à adapter selon votre configuration)
# IMPORTANT: Utilisez les IDs des valeurs, pas les noms
# Pour trouver les IDs des Request Types, créez manuellement un incident dans Jira et notez l'ID
$jsmDefaultValues = @{
    "request_type" = "14"  # ID du Request Type (ex: "Report a system problem")
    "affected_services" = @()  # Liste des services affectés (IDs) - optionnel
    "organizations" = @()  # Liste des organisations (IDs) - optionnel
}

# Priority mapping from VTOM severity to Jira priority
$priorityMapping = @{
    "critical" = "Highest"
    "high" = "High"
    "medium" = "Medium"
    "low" = "Low"
    "info" = "Lowest"
}

# Issue type mapping from VTOM alarm type to Jira issue type
$issueTypeMapping = @{
    "job_failure" = "Incident"
    "system_alert" = "Incident"
    "performance" = "Task"
    "maintenance" = "Task"
}
