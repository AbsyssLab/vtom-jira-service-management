# Visual TOM Jira Service Management Integration
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE.md)&nbsp;
[![fr](https://img.shields.io/badge/lang-fr-yellow.svg)](README-fr.md)  

This project provides scripts to create and manage Jira Service Management tickets from Visual TOM. To avoid too many isolated tickets, the script checks if a ticket already exists for the object name and is not closed.  
If it does, it will create a child ticket with the new information.  
If not, it will create a new ticket.  
If provided, the script will add the output and error logs as attachments to the ticket.

# Disclaimer
No Support and No Warranty are provided by Absyss SAS for this project and related material. The use of this project's files is at your own risk.

Absyss SAS assumes no liability for damage caused by the usage of any of the files offered here via this Github repository.

Consultings days can be requested to help for the implementation.

# Prerequisites

* Visual TOM 7.2.1f or greater (lower versions may work but without log attachment)
* Jira Service Management instance with REST API enabled
* Custom field in Jira to store the Visual TOM object name (Jobs, Applications, Agents, etc.)
* Python 3.10 or greater or PowerShell 7.0 or greater

# Quick Start

## Automatic Configuration (Recommended)

We provide interactive setup scripts that automatically discover your Jira configuration and generate the config file for you:

### PowerShell (Windows)
```powershell
.\setup_config.ps1
```

### Python (Cross-platform)
```bash
python setup_config.py
```

These scripts will:
- ✅ Connect to your Jira instance
- ✅ List available projects, issue types, and priorities
- ✅ Detect custom fields automatically
- ✅ Find Request Types for Jira Service Management
- ✅ Generate the configuration file with correct IDs

**This is the easiest way to get started!**

## Manual Configuration

If you prefer to configure manually, you can copy the template files:

```bash
# For Python
cp config.template.py config.py

# For PowerShell
cp config.template.ps1 config.ps1
```

Then edit the config file with your Jira credentials and field IDs.

# Usage

You can choose between the PowerShell script or the Python script depending on your environment.  
You need to replace FULL_PATH_TO_SCRIPT, PROJECT_KEY, ISSUE_TYPE, PRIORITY and ASSIGNEE by your values.

### PowerShell Script

1. Run the setup script or edit the config.ps1 file with your Jira credentials
2. Create an alarm in Visual TOM to trigger the script (example below for a job to be adapted)

```powershell
powershell.exe -file FULL_PATH_TO_SCRIPT\Jira_CreateTicket.ps1 -ProjectKey "PROJ" -Summary "Job {VT_JOB_FULLNAME} has failed" -Description "Job {VT_JOB_FULLNAME} has failed with error" -ObjectName "{VT_JOB_FULLNAME}" -Priority "High" -OutAttachmentName "{VT_JOB_LOG_OUT_NAME}" -OutAttachmentFile "{VT_JOB_LOG_OUT_FILE}" -ErrorAttachmentName "{VT_JOB_LOG_ERR_NAME}" -ErrorAttachmentFile "{VT_JOB_LOG_ERR_FILE}"
```

### Python Script

1. Run the setup script or edit the config.py file with your Jira credentials
2. Create an alarm in Visual TOM to trigger the script (example below for a job to be adapted)

```bash
python3 FULL_PATH_TO_SCRIPT/Jira_CreateTicket.py --projectKey PROJ --summary "Job {VT_JOB_FULLNAME} has failed" --description "Job {VT_JOB_FULLNAME} has failed with error" --objectName "{VT_JOB_FULLNAME}" --priority "High" --outAttachmentName "{VT_JOB_LOG_OUT_NAME}" --outAttachmentFile "{VT_JOB_LOG_OUT_FILE}" --errorAttachmentName "{VT_JOB_LOG_ERR_NAME}" --errorAttachmentFile "{VT_JOB_LOG_ERR_FILE}"
```

## Configuration

### Authentication

You need to create an API token in Jira:
1. Go to your Jira profile settings or directly here: https://id.atlassian.com/manage-profile/security/api-tokens
2. Navigate to Security → API tokens
3. Create a new API token
4. Encode your email and API token in base64: `echo -n "your-email@domain.com:your-api-token" | base64`

### Custom Fields

To map VTOM variables to Jira custom fields:
1. Go to your Jira project settings
2. Navigate to Fields → Custom fields
3. Note the field IDs (they start with `customfield_`)
4. Update the `custom_field_mappings` in your config file

### Priority and Issue Type Mapping

The scripts support automatic mapping of VTOM severity levels to Jira priorities and alarm types to issue types. Configure these mappings in your config file.

# Available Actions

## Global Objectives

- ➡️ Automatically create Jira tickets from VTOM alarms
- ➡️ Avoid duplicate tickets by reusing an existing ticket whenever possible
- ➡️ Track successive alarms (through linked tickets, comments, and attachments)

The script:
1. Connects to Jira using the REST API
2. Analyzes the received VTOM alarm (via CLI parameters)
3. Checks whether an open ticket already exists for the same VTOM object
4. Depending on the situation:
  Creates a new ticket, or
  Creates a ticket linked to an existing one
5. Adds:
  Attachments (log files)
  A timestamped comment

## Script Arguments

The script is executed from the command line with the following parameters:
- --projectKey → Jira project key
- --summary → Ticket summary
- --description → Detailed ticket description
- --objectName → VTOM object name (Applications, Jobs...)
- --severity → VTOM alarm severity
- --alarmType → VTOM alarm type
- Log files to attach (stdout / stderr)

# License
This project is licensed under the Apache 2.0 License - see the [LICENSE](license) file for details


# Code of Conduct
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.1%20adopted-ff69b4.svg)](code-of-conduct.md)  
Absyss SAS has adopted the [Contributor Covenant](CODE_OF_CONDUCT.md) as its Code of Conduct, and we expect project participants to adhere to it. Please read the [full text](CODE_OF_CONDUCT.md) so that you can understand what actions will and will not be tolerated.
