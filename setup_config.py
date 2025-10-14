#!/usr/bin/env python3
"""
Interactive Configuration Setup for VTOM Jira Service Management Integration

This script helps you configure the integration by automatically discovering
available options in your Jira instance and generating the config.py file.

Usage: python setup_config.py
"""

import requests
import sys
import base64
from typing import Dict, List, Optional, Tuple


class JiraConfigSetup:
    """Interactive setup for Jira configuration"""
    
    def __init__(self):
        self.base_url = None
        self.auth_token = None
        self.session = None
        self.config = {}
    
    def print_header(self, text: str):
        """Print a formatted header"""
        print("\n" + "="*70)
        print(f"  {text}")
        print("="*70)
    
    def print_step(self, step: int, text: str):
        """Print a step header"""
        print(f"\n[Step {step}] {text}")
        print("-" * 70)
    
    def get_input(self, prompt: str, default: str = None) -> str:
        """Get user input with optional default value"""
        if default:
            user_input = input(f"{prompt} [{default}]: ").strip()
            return user_input if user_input else default
        return input(f"{prompt}: ").strip()
    
    def get_choice(self, prompt: str, options: List[Tuple[str, str]], allow_none: bool = False) -> Optional[str]:
        """
        Display options and get user choice
        options: List of (id, name) tuples
        Returns: selected ID or None
        """
        print(f"\n{prompt}")
        for idx, (item_id, item_name) in enumerate(options, 1):
            print(f"  {idx}. {item_name} (ID: {item_id})")
        
        if allow_none:
            print(f"  0. None / Skip")
        
        while True:
            try:
                choice = input("\nEnter your choice (number): ").strip()
                choice_num = int(choice)
                
                if allow_none and choice_num == 0:
                    return None
                
                if 1 <= choice_num <= len(options):
                    selected_id, selected_name = options[choice_num - 1]
                    print(f"Selected: {selected_name}")
                    return selected_id
                else:
                    print(f"Invalid choice. Please enter a number between {'0' if allow_none else '1'} and {len(options)}")
            except ValueError:
                print("Invalid input. Please enter a number.")
    
    def test_connection(self) -> bool:
        """Test connection to Jira"""
        try:
            response = self.session.get(f'{self.base_url}/rest/api/3/myself')
            response.raise_for_status()
            user_data = response.json()
            print(f"✓ Successfully connected as: {user_data.get('displayName', 'Unknown')}")
            return True
        except requests.exceptions.RequestException as e:
            print(f"✗ Connection failed: {e}")
            return False
    
    def get_projects(self) -> List[Tuple[str, str]]:
        """Get list of available projects"""
        try:
            response = self.session.get(f'{self.base_url}/rest/api/3/project')
            response.raise_for_status()
            projects = response.json()
            return [(p['key'], f"{p['name']} ({p['key']})") for p in projects]
        except requests.exceptions.RequestException as e:
            print(f"Error fetching projects: {e}")
            return []
    
    def get_issue_types(self, project_key: str) -> List[Tuple[str, str]]:
        """Get issue types for a project"""
        try:
            response = self.session.get(f'{self.base_url}/rest/api/3/project/{project_key}')
            response.raise_for_status()
            project_data = response.json()
            return [(it['name'], it['name']) for it in project_data.get('issueTypes', [])]
        except requests.exceptions.RequestException as e:
            print(f"Error fetching issue types: {e}")
            return []
    
    def get_priorities(self) -> List[Tuple[str, str]]:
        """Get available priorities"""
        try:
            response = self.session.get(f'{self.base_url}/rest/api/3/priority')
            response.raise_for_status()
            priorities = response.json()
            return [(p['name'], p['name']) for p in priorities]
        except requests.exceptions.RequestException as e:
            print(f"Error fetching priorities: {e}")
            return []
    
    def get_custom_fields(self, project_key: str, issue_type: str) -> Dict[str, str]:
        """Get custom fields for a project and issue type"""
        try:
            response = self.session.get(
                f'{self.base_url}/rest/api/3/issue/createmeta',
                params={
                    'projectKeys': project_key,
                    'expand': 'projects.issuetypes.fields'
                }
            )
            response.raise_for_status()
            data = response.json()
            
            custom_fields = {}
            for project in data.get('projects', []):
                for it in project.get('issuetypes', []):
                    if it['name'] == issue_type:
                        fields = it.get('fields', {})
                        for field_id, field_info in fields.items():
                            if field_id.startswith('customfield_'):
                                field_name = field_info.get('name', 'Unknown')
                                custom_fields[field_id] = field_name
            
            return custom_fields
        except requests.exceptions.RequestException as e:
            print(f"Error fetching custom fields: {e}")
            return {}
    
    def get_request_types(self) -> List[Tuple[str, str]]:
        """Get available request types from Service Desk"""
        try:
            response = self.session.get(f'{self.base_url}/rest/servicedeskapi/servicedesk')
            response.raise_for_status()
            service_desks = response.json()
            
            request_types = []
            for sd in service_desks.get('values', []):
                sd_id = sd.get('id')
                if sd_id:
                    rt_response = self.session.get(
                        f'{self.base_url}/rest/servicedeskapi/servicedesk/{sd_id}/requesttype'
                    )
                    if rt_response.status_code == 200:
                        rts = rt_response.json()
                        for rt in rts.get('values', []):
                            request_types.append((str(rt['id']), f"{rt['name']} (Service Desk: {sd.get('projectName', 'Unknown')})"))
            
            return request_types
        except requests.exceptions.RequestException as e:
            print(f"Error fetching request types: {e}")
            return []
    
    def find_custom_field_by_name(self, custom_fields: Dict[str, str], search_terms: List[str]) -> Optional[str]:
        """Find custom field ID by searching for terms in the name"""
        for field_id, field_name in custom_fields.items():
            field_name_lower = field_name.lower()
            if any(term.lower() in field_name_lower for term in search_terms):
                return field_id
        return None
    
    def setup_connection(self):
        """Step 1: Setup connection to Jira"""
        self.print_step(1, "Connection Setup")
        
        print("\nTo connect to Jira, you need:")
        print("  1. Your Jira instance URL (e.g., https://your-domain.atlassian.net)")
        print("  2. An API token (create one at: https://id.atlassian.com/manage-profile/security/api-tokens)")
        
        self.base_url = self.get_input("\nEnter your Jira instance URL").rstrip('/')
        
        print("\nFor the API token, you need to provide: email:api_token encoded in base64")
        print("Example: echo -n 'your-email@domain.com:your-api-token' | base64")
        
        use_manual = self.get_input("Do you want to enter base64 token manually? (y/n)", "n").lower()
        
        if use_manual == 'y':
            self.auth_token = self.get_input("Enter your base64 encoded token")
        else:
            email = self.get_input("Enter your Jira email")
            api_token = self.get_input("Enter your API token")
            credentials = f"{email}:{api_token}"
            self.auth_token = base64.b64encode(credentials.encode()).decode()
        
        # Initialize session
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Basic {self.auth_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
        
        print("\nTesting connection...")
        if not self.test_connection():
            print("\n✗ Failed to connect to Jira. Please check your credentials.")
            sys.exit(1)
        
        self.config['jira_base_url'] = self.base_url
        self.config['jira_auth_token'] = self.auth_token
    
    def setup_project(self):
        """Step 2: Select project"""
        self.print_step(2, "Project Selection")
        
        print("\nFetching available projects...")
        projects = self.get_projects()
        
        if not projects:
            print("No projects found or unable to fetch projects.")
            sys.exit(1)
        
        project_key = self.get_choice("Select your project:", projects)
        self.config['default_project_key'] = project_key
        
        print(f"\n✓ Project selected: {project_key}")
    
    def setup_issue_type(self):
        """Step 3: Select issue type"""
        self.print_step(3, "Issue Type Selection")
        
        print("\nFetching available issue types...")
        issue_types = self.get_issue_types(self.config['default_project_key'])
        
        if not issue_types:
            print("No issue types found.")
            self.config['default_issue_type'] = "Incident"
            return
        
        issue_type = self.get_choice("Select the default issue type for VTOM alarms:", issue_types)
        self.config['default_issue_type'] = issue_type
        
        print(f"\n✓ Issue type selected: {issue_type}")
    
    def setup_priority(self):
        """Step 4: Select priority"""
        self.print_step(4, "Priority Selection")
        
        print("\nFetching available priorities...")
        priorities = self.get_priorities()
        
        if not priorities:
            print("No priorities found.")
            self.config['default_priority'] = "High"
            return
        
        priority = self.get_choice("Select the default priority for VTOM alarms:", priorities)
        self.config['default_priority'] = priority
        
        print(f"\n✓ Priority selected: {priority}")
    
    def setup_custom_fields(self):
        """Step 5: Configure custom fields"""
        self.print_step(5, "Custom Fields Configuration")
        
        print("\nFetching custom fields...")
        custom_fields = self.get_custom_fields(
            self.config['default_project_key'],
            self.config['default_issue_type']
        )
        
        if not custom_fields:
            print("No custom fields found.")
            return
        
        print(f"\nFound {len(custom_fields)} custom fields")
        
        # VTOM Object Name field
        print("\n--- VTOM Object Name Field ---")
        print("This field is used to track VTOM objects and detect duplicate issues.")
        
        vtom_field = self.find_custom_field_by_name(custom_fields, ['vtom', 'object', 'name'])
        if vtom_field:
            print(f"Suggested field: {custom_fields[vtom_field]} ({vtom_field})")
            use_suggested = self.get_input("Use this field? (y/n)", "y").lower()
            if use_suggested != 'y':
                vtom_field = None
        
        if not vtom_field:
            field_options = [(fid, f"{fname} ({fid})") for fid, fname in custom_fields.items()]
            vtom_field = self.get_choice("Select the field for VTOM object name:", field_options, allow_none=True)
        
        self.config['vtom_object_name_field'] = vtom_field
        
        # Request Type field (for JSM)
        print("\n--- Request Type Field (Jira Service Management) ---")
        print("This field is required for JSM to categorize incidents.")
        
        request_type_field = self.find_custom_field_by_name(custom_fields, ['request', 'type'])
        if request_type_field:
            print(f"Found Request Type field: {request_type_field}")
            self.config['request_type_field'] = request_type_field
        else:
            print("Request Type field not found. You may need to configure it manually.")
            self.config['request_type_field'] = None
        
        # Affected Services field
        print("\n--- Affected Services Field (Optional) ---")
        services_field = self.find_custom_field_by_name(custom_fields, ['affected', 'service', 'services'])
        if services_field:
            print(f"Found Affected Services field: {services_field}")
            self.config['affected_services_field'] = services_field
        else:
            self.config['affected_services_field'] = None
        
        # Organizations field
        print("\n--- Organizations Field (Optional) ---")
        orgs_field = self.find_custom_field_by_name(custom_fields, ['organization', 'organisations'])
        if orgs_field:
            print(f"Found Organizations field: {orgs_field}")
            self.config['organizations_field'] = orgs_field
        else:
            self.config['organizations_field'] = None
    
    def setup_request_type(self):
        """Step 6: Select request type"""
        self.print_step(6, "Request Type Selection (JSM)")
        
        if not self.config.get('request_type_field'):
            print("Request Type field not configured. Skipping...")
            return
        
        print("\nFetching available request types...")
        request_types = self.get_request_types()
        
        if not request_types:
            print("No request types found or Service Desk API not available.")
            print("You may need to configure the Request Type ID manually.")
            return
        
        rt_id = self.get_choice("Select the default request type for VTOM incidents:", request_types)
        self.config['default_request_type_id'] = rt_id
        
        print(f"\n✓ Request type selected: ID {rt_id}")
    
    def generate_config_file(self):
        """Step 7: Generate config.py file"""
        self.print_step(7, "Generate Configuration File")
        
        config_content = f'''# Jira Service Management Configuration
# Generated by setup_config.py

# Jira instance configuration
jira_base_url = "{self.config.get('jira_base_url', '')}"
jira_auth_token = "{self.config.get('jira_auth_token', '')}"

# Default values for issue creation
default_project_key = "{self.config.get('default_project_key', 'PROJ')}"
default_issue_type = "{self.config.get('default_issue_type', 'Incident')}"
default_priority = "{self.config.get('default_priority', 'High')}"
default_assignee = None  # Set to email/username if you want to auto-assign

# Custom field mappings (required for Jira Service Management)
custom_field_mappings = {{
    "vtom_object_name": "{self.config.get('vtom_object_name_field', 'customfield_10055')}",
    "request_type": "{self.config.get('request_type_field', 'customfield_10010')}",
    "affected_services": "{self.config.get('affected_services_field', 'customfield_10043')}",
    "organizations": "{self.config.get('organizations_field', 'customfield_10002')}",
}}

# Default values for JSM fields
jsm_default_values = {{
    "request_type": "{self.config.get('default_request_type_id', '14')}",
    "affected_services": [],
    "organizations": []
}}

# Priority mapping from Visual TOM severity to Jira priority
priority_mapping = {{
    "critical": "Highest",
    "high": "High", 
    "medium": "Medium",
    "low": "Low",
    "info": "Lowest"
}}

# Issue type mapping from Visual TOM alarm type to Jira issue type
issue_type_mapping = {{
    "job_failure": "Incident",
    "system_alert": "Incident", 
    "performance": "Task",
    "maintenance": "Task"
}}
'''
        
        print("\nConfiguration file content:")
        print("-" * 70)
        print(config_content)
        print("-" * 70)
        
        save = self.get_input("\nSave this configuration to config.py? (y/n)", "y").lower()
        
        if save == 'y':
            with open('config.py', 'w', encoding='utf-8') as f:
                f.write(config_content)
            print("\n✓ Configuration saved to config.py")
            print("\nYou can now use the integration scripts:")
            print("  - Jira_CreateTicket.py (Python)")
            print("  - Jira_CreateTicket.ps1 (PowerShell)")
        else:
            print("\nConfiguration not saved. You can copy the content above manually.")
    
    def run(self):
        """Run the interactive setup"""
        self.print_header("VTOM Jira Service Management - Configuration Setup")
        print("\nThis wizard will help you configure the integration with your Jira instance.")
        print("You will be asked to select options from your Jira configuration.")
        
        try:
            self.setup_connection()
            self.setup_project()
            self.setup_issue_type()
            self.setup_priority()
            self.setup_custom_fields()
            self.setup_request_type()
            self.generate_config_file()
            
            self.print_header("Setup Complete!")
            print("\n✓ Configuration setup completed successfully!")
            print("\nNext steps:")
            print("  1. Review the generated config.py file")
            print("  2. Test the integration with a sample alarm")
            print("  3. Configure VTOM to use the scripts")
            
        except KeyboardInterrupt:
            print("\n\nSetup cancelled by user.")
            sys.exit(0)
        except Exception as e:
            print(f"\n\nError during setup: {e}")
            sys.exit(1)


def main():
    """Main entry point"""
    setup = JiraConfigSetup()
    setup.run()


if __name__ == '__main__':
    main()

