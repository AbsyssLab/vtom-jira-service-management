# Jira Service Management Configuration Template
# Copy this file to config.py and update with your Jira instance details

# Jira instance configuration
jira_base_url = "https://your-domain.atlassian.net"  # Replace with your Jira instance URL
jira_auth_token = "YOUR_BASE64_ENCODED_EMAIL:API_TOKEN"  # Replace with your base64 encoded email:api_token

# Default values for issue creation
default_project_key = "PROJ"  # Replace with your Jira project key
default_issue_type = "[System] Incident"  # Use the exact name from your Jira project
default_priority = "High"
default_assignee = None  # Set to email/username if you want to auto-assign

# Custom field mappings (required for Jira Service Management)
# Map VTOM variables to Jira custom fields
# To find custom field IDs, go to Jira Settings > Issues > Custom fields
custom_field_mappings = {
    "vtom_object_name": "customfield_10055",  # Replace with actual custom field ID for VTOM object tracking
    # Required fields for Jira Service Management
    "request_type": "customfield_10010",  # Request Type - REQUIRED for JSM
    "affected_services": "customfield_10043",  # Affected services (optional)
    "organizations": "customfield_10002",  # Organizations (optional)
}

# Default values for JSM fields (adapt to your configuration)
# IMPORTANT: Use the IDs of the values, not the names
# To find Request Type IDs, use the find_request_types.py script
jsm_default_values = {
    "request_type": "14",  # Request Type ID (ex: "Report a system problem")
    "affected_services": [],  # List of affected services (IDs) - optional
    "organizations": []  # List of organizations (IDs) - optional
}

# Priority mapping from Visual TOM severity to Jira priority
priority_mapping = {
    "critical": "Highest",
    "high": "High", 
    "medium": "Medium",
    "low": "Low",
    "info": "Lowest"
}

# Issue type mapping from VTOM alarm type to Jira issue type
issue_type_mapping = {
    "job_failure": "Incident",
    "system_alert": "Incident", 
    "performance": "Task",
    "maintenance": "Task"
}