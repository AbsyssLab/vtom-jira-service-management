#!/usr/bin/env python3
"""
Jira Service Management Integration for Visual TOM
Creates and manages Jira tickets from Visual TOM alarms.

This script checks if a ticket already exists for the object name and is not closed.
If it does, it will create a child ticket with the new information.
If not, it will create a new ticket.
If provided, the script will add the output and error logs as attachments to the ticket.
"""

import argparse
import base64
import json
import os
import sys
import requests
from datetime import datetime
from typing import Dict, List, Optional, Tuple

# Import configuration
try:
    from config import (
        jira_base_url,
        jira_auth_token,
        default_project_key,
        default_issue_type,
        default_priority,
        default_assignee,
        custom_field_mappings,
        priority_mapping,
        issue_type_mapping,
        jsm_default_values
    )
except ImportError:
    print("Error: config.py not found. Please copy config.template.py to config.py and configure it.")
    sys.exit(1)


class JiraIntegration:
    """Jira Service Management integration class"""
    
    def __init__(self, base_url: str, auth_token: str):
        self.base_url = base_url.rstrip('/')
        self.auth_token = auth_token
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Basic {auth_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
    
    def get_issue_type_id(self, project_key: str, issue_type_name: str) -> Optional[str]:
        """
        Get the issue type ID for a given project and issue type name
        """
        try:
            response = self.session.get(f'{self.base_url}/rest/api/3/project/{project_key}')
            response.raise_for_status()
            
            project_data = response.json()
            for issue_type in project_data.get('issueTypes', []):
                if issue_type['name'].lower() == issue_type_name.lower():
                    return issue_type['id']
            
            # If not found, try to get all issue types
            response = self.session.get(f'{self.base_url}/rest/api/3/issuetype')
            response.raise_for_status()
            
            issue_types = response.json()
            for issue_type in issue_types:
                if issue_type['name'].lower() == issue_type_name.lower():
                    return issue_type['id']
            
            return None
            
        except requests.exceptions.RequestException as e:
            print(f"Error getting issue type ID: {e}")
            return None
    
    def get_priority_id(self, priority_name: str) -> Optional[str]:
        """
        Get the priority ID for a given priority name
        """
        try:
            response = self.session.get(f'{self.base_url}/rest/api/3/priority')
            response.raise_for_status()
            
            priorities = response.json()
            for priority in priorities:
                if priority['name'].lower() == priority_name.lower():
                    return priority['id']
            
            return None
            
        except requests.exceptions.RequestException as e:
            print(f"Error getting priority ID: {e}")
            return None
    
    def search_existing_issue(self, object_name: str, project_key: str) -> Optional[Dict]:
        """
        Search for existing open issues related to the object name using custom field
        Uses the new /rest/api/3/search/jql API endpoint
        """
        # Get the custom field ID for vtom_object_name
        vtom_field_id = custom_field_mappings.get('vtom_object_name')
        if not vtom_field_id:
            print("Warning: vtom_object_name custom field not configured, skipping existing issue search")
            return None
        
        try:
            print(f"Searching for existing issues with VTOM object: {object_name}")
            
            # Use the new JQL API endpoint
            jql = f'project = {project_key} ORDER BY created DESC'
            
            response = self.session.post(
                f'{self.base_url}/rest/api/3/search/jql',
                json={
                    'jql': jql,
                    'maxResults': 100,
                    'fields': ['summary', 'status', vtom_field_id]
                }
            )
            response.raise_for_status()
            
            data = response.json()
            
            # Filter issues in memory
            for issue in data.get('issues', []):
                # Check if issue is not closed
                status = issue['fields'].get('status', {}).get('name', '')
                if status.lower() in ['done', 'closed', 'resolved']:
                    continue
                
                # Check if vtom_object_name matches
                vtom_value = issue['fields'].get(vtom_field_id)
                if vtom_value and vtom_value == object_name:
                    print(f"Found existing issue: {issue['key']} with matching VTOM object name")
                    return issue
            
            # No matching issue found
            print("No existing open issue found for this VTOM object")
            return None
            
        except requests.exceptions.RequestException as e:
            print(f"Error searching for existing issues: {e}")
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_detail = e.response.json()
                    print(f"Error details: {error_detail}")
                except:
                    pass
            return None
    
    def create_issue(self, project_key: str, issue_type: str, summary: str, 
                    description: str, priority: str, assignee: Optional[str] = None,
                    custom_fields: Optional[Dict] = None) -> Optional[Dict]:
        """
        Create a new Jira issue
        """
        # First, get the issue type ID
        issue_type_id = self.get_issue_type_id(project_key, issue_type)
        if not issue_type_id:
            print(f"Error: Issue type '{issue_type}' not found in project '{project_key}'")
            return None
        
        # Get priority ID
        priority_id = self.get_priority_id(priority)
        if not priority_id:
            print(f"Error: Priority '{priority}' not found")
            return None
        
        issue_data = {
            'fields': {
                'project': {'key': project_key},
                'issuetype': {'id': issue_type_id},
                'summary': summary,
                'description': {
                    'type': 'doc',
                    'version': 1,
                    'content': [
                        {
                            'type': 'paragraph',
                            'content': [
                                {
                                    'type': 'text',
                                    'text': description
                                }
                            ]
                        }
                    ]
                },
                'priority': {'id': priority_id}
            }
        }
        
        if assignee:
            issue_data['fields']['assignee'] = {'emailAddress': assignee}
        
        if custom_fields:
            issue_data['fields'].update(custom_fields)
        
        try:
            response = self.session.post(
                f'{self.base_url}/rest/api/3/issue',
                json=issue_data
            )
            response.raise_for_status()
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"Error creating issue: {e}")
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_detail = e.response.json()
                    print(f"Error details: {error_detail}")
                except:
                    print(f"Response content: {e.response.text}")
            return None
    
    def create_subtask(self, parent_key: str, project_key: str, issue_type: str, 
                      summary: str, description: str, priority: str,
                      assignee: Optional[str] = None, custom_fields: Optional[Dict] = None) -> Optional[Dict]:
        """
        Create a subtask for an existing issue
        """
        # Get issue type ID for subtask
        issue_type_id = self.get_issue_type_id(project_key, 'Sub-task')
        if not issue_type_id:
            print(f"Error: Sub-task issue type not found in project '{project_key}'")
            return None
        
        # Get priority ID
        priority_id = self.get_priority_id(priority)
        if not priority_id:
            print(f"Error: Priority '{priority}' not found")
            return None
        
        issue_data = {
            'fields': {
                'project': {'key': project_key},
                'issuetype': {'id': issue_type_id},
                'parent': {'key': parent_key},
                'summary': summary,
                'description': {
                    'type': 'doc',
                    'version': 1,
                    'content': [
                        {
                            'type': 'paragraph',
                            'content': [
                                {
                                    'type': 'text',
                                    'text': description
                                }
                            ]
                        }
                    ]
                },
                'priority': {'id': priority_id}
            }
        }
        
        if assignee:
            issue_data['fields']['assignee'] = {'emailAddress': assignee}
        
        if custom_fields:
            issue_data['fields'].update(custom_fields)
        
        try:
            response = self.session.post(
                f'{self.base_url}/rest/api/3/issue',
                json=issue_data
            )
            response.raise_for_status()
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"Error creating subtask: {e}")
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_detail = e.response.json()
                    print(f"Error details: {error_detail}")
                except:
                    print(f"Response content: {e.response.text}")
            return None
    
    def add_attachment(self, issue_key: str, file_path: str, filename: str) -> bool:
        """
        Add an attachment to a Jira issue
        """
        if not os.path.exists(file_path):
            print(f"Warning: Attachment file {file_path} does not exist")
            return False
        
        try:
            with open(file_path, 'rb') as f:
                files = {'file': (filename, f, 'application/octet-stream')}
                # Important: Ne pas inclure Content-Type dans les headers pour les uploads de fichiers
                # Jira nécessite X-Atlassian-Token pour éviter les attaques CSRF
                headers = {
                    'Authorization': f'Basic {self.auth_token}',
                    'X-Atlassian-Token': 'no-check'
                }
                
                # Créer une nouvelle session sans le Content-Type par défaut
                response = requests.post(
                    f'{self.base_url}/rest/api/3/issue/{issue_key}/attachments',
                    files=files,
                    headers=headers
                )
                response.raise_for_status()
                
                return True
                
        except requests.exceptions.RequestException as e:
            print(f"Error adding attachment: {e}")
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_detail = e.response.json()
                    print(f"Error details: {error_detail}")
                except:
                    print(f"Response content: {e.response.text}")
            return False
        except IOError as e:
            print(f"Error reading file {file_path}: {e}")
            return False
    
    def add_comment(self, issue_key: str, comment: str) -> bool:
        """
        Add a comment to a Jira issue
        """
        comment_data = {
            'body': {
                'type': 'doc',
                'version': 1,
                'content': [
                    {
                        'type': 'paragraph',
                        'content': [
                            {
                                'type': 'text',
                                'text': comment
                            }
                        ]
                    }
                ]
            }
        }
        
        try:
            response = self.session.post(
                f'{self.base_url}/rest/api/3/issue/{issue_key}/comment',
                json=comment_data
            )
            response.raise_for_status()
            
            return True
            
        except requests.exceptions.RequestException as e:
            print(f"Error adding comment: {e}")
            return False


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Create Jira ticket from VTOM alarm')
    
    # Required arguments
    parser.add_argument('--projectKey', required=True, help='Jira project key')
    parser.add_argument('--summary', required=True, help='Issue summary')
    parser.add_argument('--description', required=True, help='Issue description')
    parser.add_argument('--objectName', required=True, help='VTOM object name')
    
    # Optional arguments
    parser.add_argument('--issueType', default=default_issue_type, help='Issue type')
    parser.add_argument('--priority', default=default_priority, help='Issue priority')
    parser.add_argument('--assignee', help='Issue assignee email')
    parser.add_argument('--outAttachmentName', help='Output log attachment name')
    parser.add_argument('--outAttachmentFile', help='Output log attachment file path')
    parser.add_argument('--errorAttachmentName', help='Error log attachment name')
    parser.add_argument('--errorAttachmentFile', help='Error log attachment file path')
    parser.add_argument('--severity', help='VTOM alarm severity (for priority mapping)')
    parser.add_argument('--alarmType', help='VTOM alarm type (for issue type mapping)')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode to show available issue types and priorities')
    
    args = parser.parse_args()
    
    # Initialize Jira integration
    jira = JiraIntegration(jira_base_url, jira_auth_token)
    
    # Debug mode - show available issue types and priorities
    if args.debug:
        print("=== DEBUG MODE ===")
        print(f"Project: {args.projectKey}")
        
        # Get project info
        try:
            response = jira.session.get(f'{jira.base_url}/rest/api/3/project/{args.projectKey}')
            response.raise_for_status()
            project_data = response.json()
            print(f"Project name: {project_data.get('name', 'Unknown')}")
            print("Available issue types:")
            for issue_type in project_data.get('issueTypes', []):
                print(f"  - {issue_type['name']} (ID: {issue_type['id']})")
        except Exception as e:
            print(f"Error getting project info: {e}")
        
        # Get priorities
        try:
            response = jira.session.get(f'{jira.base_url}/rest/api/3/priority')
            response.raise_for_status()
            priorities = response.json()
            print("Available priorities:")
            for priority in priorities:
                print(f"  - {priority['name']} (ID: {priority['id']})")
        except Exception as e:
            print(f"Error getting priorities: {e}")
        
        print("=== END DEBUG ===")
        return
    
    # Map priority and issue type if mappings are provided
    priority = args.priority
    if args.severity and args.severity.lower() in priority_mapping:
        priority = priority_mapping[args.severity.lower()]
    
    issue_type = args.issueType
    if args.alarmType and args.alarmType.lower() in issue_type_mapping:
        issue_type = issue_type_mapping[args.alarmType.lower()]
    
    # Prepare custom fields
    custom_fields = {}
    if custom_field_mappings:
        # Map vtom_object_name to the correct custom field ID
        vtom_field_id = custom_field_mappings.get('vtom_object_name')
        if vtom_field_id:
            custom_fields[vtom_field_id] = args.objectName
        
        # Map JSM fields with default values
        if jsm_default_values:
            for field_name, field_id in custom_field_mappings.items():
                if field_name in jsm_default_values:
                    default_value = jsm_default_values[field_name]
                    if default_value:  # Only add if not empty
                        custom_fields[field_id] = default_value
        
        # Map other custom fields if they exist
        for field_name, field_id in custom_field_mappings.items():
            if field_name == 'vtom_job_name':
                custom_fields[field_id] = args.objectName
    
    # Search for existing issue
    existing_issue = jira.search_existing_issue(args.objectName, args.projectKey)
    
    if existing_issue:
        print(f"Found existing issue: {existing_issue['key']}")
        
        # For JSM, create a new linked issue instead of subtask
        # Add reference to parent in summary and description
        linked_summary = f"{args.summary} (Related to {existing_issue['key']})"
        linked_description = f"This issue is related to existing issue {existing_issue['key']}\n\nVTOM Object: {args.objectName}\n\n{args.description}"
        
        result = jira.create_issue(
            args.projectKey,
            issue_type,
            linked_summary,
            linked_description,
            priority,
            args.assignee,
            custom_fields
        )
        
        if result:
            print(f"Created linked issue: {result['key']}")
            issue_key = result['key']
            
            # Add a link between the two issues
            try:
                link_data = {
                    'type': {'name': 'Relates'},
                    'inwardIssue': {'key': issue_key},
                    'outwardIssue': {'key': existing_issue['key']}
                }
                link_response = jira.session.post(
                    f'{jira.base_url}/rest/api/3/issueLink',
                    json=link_data
                )
                if link_response.status_code == 201:
                    print(f"Linked {issue_key} to {existing_issue['key']}")
            except:
                print(f"Warning: Could not create link between issues")
        else:
            print("Failed to create linked issue")
            sys.exit(1)
    else:
        # Create new issue
        result = jira.create_issue(
            args.projectKey,
            issue_type,
            args.summary,
            args.description,
            priority,
            args.assignee,
            custom_fields
        )
        
        if result:
            print(f"Created new issue: {result['key']}")
            issue_key = result['key']
        else:
            print("Failed to create issue")
            sys.exit(1)
    
    # Add attachments if provided
    if args.outAttachmentFile and args.outAttachmentName:
        if jira.add_attachment(issue_key, args.outAttachmentFile, args.outAttachmentName):
            print(f"Added output log attachment: {args.outAttachmentName}")
    
    if args.errorAttachmentFile and args.errorAttachmentName:
        if jira.add_attachment(issue_key, args.errorAttachmentFile, args.errorAttachmentName):
            print(f"Added error log attachment: {args.errorAttachmentName}")
    
    # Add comment with timestamp
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    comment = f"VTOM alarm processed at {timestamp}"
    if jira.add_comment(issue_key, comment):
        print("Added timestamp comment")


if __name__ == '__main__':
    main()
