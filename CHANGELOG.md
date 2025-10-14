# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-14

### Added
- Initial release of VTOM Jira Service Management Integration
- Python script (`Jira_CreateTicket.py`) for creating and managing Jira tickets from Visual TOM alarms
- PowerShell script (`Jira_CreateTicket.ps1`) for Windows environments
- Automatic configuration setup scripts:
  - `setup_config.py` - Interactive Python configuration wizard
  - `setup_config.ps1` - Interactive PowerShell configuration wizard
- Configuration templates:
  - `config.template.py` - Python configuration template
  - `config.template.ps1` - PowerShell configuration template
- Support for Jira Service Management specific features:
  - Request Type configuration
  - Custom fields mapping (vtom_object_name, affected_services, organizations)
  - Automatic Request Type detection via Service Desk API
- Smart ticket management:
  - Search for existing open tickets by VTOM object name
  - Create linked tickets for recurring alarms instead of duplicates
  - Automatic issue linking with "Relates" relationship
- Attachment support:
  - Upload VTOM job output logs
  - Upload VTOM job error logs
- Priority and issue type mapping:
  - Map VTOM severity levels to Jira priorities
  - Map VTOM alarm types to Jira issue types
- Comprehensive documentation:
  - English README with quick start guide
  - French README (README-fr.md)
  - Configuration examples and usage instructions
- API compatibility:
  - Support for new Jira API endpoint (`/rest/api/3/search/jql`)
  - Automatic detection of issue types and priorities
  - Custom field discovery and configuration

### Features
- **Automatic Configuration**: Interactive wizards that discover Jira configuration automatically
- **Duplicate Prevention**: Tracks VTOM objects to avoid creating duplicate tickets
- **JSM Integration**: Full support for Jira Service Management Request Types and workflows
- **Flexible Deployment**: Choose between Python or PowerShell based on your environment
- **Attachment Management**: Automatically attach VTOM logs to tickets for troubleshooting
- **Bilingual Support**: Documentation available in English and French

### Technical Details
- Requires Visual TOM 7.2.1f or greater (lower versions may work without log attachment)
- Requires Python 3.10+ or PowerShell 7.0+
- Uses Jira REST API v3
- Supports base64 encoded API token authentication
- Implements proper error handling and logging

### Known Limitations
- JQL search with custom fields requires the new `/rest/api/3/search/jql` endpoint
- Sub-tasks are not supported in JSM; linked issues are created instead
- Request Type ID must be configured manually or via setup script

[1.0.0]: https://github.com/AbsyssLab/vtom-jira-service-management/releases/tag/v1.0.0

