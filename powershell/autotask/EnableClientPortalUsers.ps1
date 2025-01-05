###########################################################
# File: EnableClientPortalUsers.ps1
# Author: Tom Lasswell
# Email: lasswellt@gmail.com
# Website: https://lasswell.me
# Repository: https://github.com/lasswellt
#
# Description: This PowerShell script enables all users to
#              have access to the simple version of the
#              client portal in Autotask. It can be run
#              periodically to automate the process of
#              enabling client portal users.
#
# Notes:
#  - Adjust the $companies filter as necessary to include
#    or exclude specific customer categories.
#  - Currently handles companies with 500 or fewer
#    contacts. For larger datasets, enhancements are needed
#    to support pagination.
#
# Disclaimer: Use this script at your own risk. Ensure it
#              is tested in a development environment
#              before production use.
#
# PowerShell Help Info:
# .SYNOPSIS
#   Enables all users to access the simple version of the
#   client portal in Autotask.
# .DESCRIPTION
#   This script queries companies and their contacts to
#   identify users without active client portal accounts
#   and enables them.
# .NOTES
#   File Name: EnableClientPortalUsers.ps1
#   Author: Tom Lasswell
#   Email: lasswellt@gmail.com
#   Website: https://lasswell.me
#   Repository: https://github.com/lasswellt
# .EXAMPLE
#   .\EnableClientPortalUsers.ps1
#   Runs the script to enable client portal users.
###########################################################

# Function to generate a secure password
Function New-SecurePassword {
    $Password = "!?@#$%^&*0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".ToCharArray()
    ($Password | Get-Random -Count 10) -Join ''
}

# Environment variables for Autotask API credentials
$at_uri = $env:at_uri
$at_integrationcode = $env:at_integrationcode
$at_username = $env:at_username
$at_secret = $env:at_secret

# Define headers for Autotask API requests
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("ApiIntegrationcode", $at_integrationcode)
$headers.Add("Content-Type", 'application/json')
$headers.Add("UserName", $at_username)
$headers.Add("Secret", $at_secret)

# Retrieve companies based on specific category filter
$companies = (Invoke-RestMethod -Uri ($at_uri + '/v1.0/Companies/query?search={"IncludeFields": ["id", "companyName","companyNumber","isActive"],"filter":[{"op":"eq","field":"companyCategoryID","value":"101"}]}') -Headers $headers -Method Get).items

# Process each company
foreach ($company in $companies | Select-Object -Skip 3) {
    # Retrieve active contacts for the company
    $contacts = (Invoke-RestMethod -Uri ($at_uri + '/v1.0/Contacts/query?search={"IncludeFields": ["id", "firstName","lastName","isActive","emailAddress"],"filter":[{"op":"and","items":[{"op":"eq","field":"companyID","value":"' + $company.id + '"},{"op":"eq","field":"isActive","value":"true"}]}]}') -Headers $headers -Method Get).items

    $query = $null
    $x = 0; $y = 0
    $clientportal = @()

    # Query and collect existing client portal users
    do {
        foreach ($contact in $contacts) {
            if ($query) {
                $query += ',{"op":"eq","field":"contactID","value":"' + $contact.id + '"}'
            } else {
                $query = '{"op":"eq","field":"contactID","value":"' + $contact.id + '"}'
            }

            $y++; $x++

            if ($x -eq $contacts.Count) { $y = 100 }

            if ($y -eq 100) {
                $postbody = '{"filter":[{"op":"or","items":[' + $query + ']}]}'
                $clientportal += (Invoke-RestMethod -Uri ($at_uri + '/v1.0/ClientPortalUsers/query') -Body $postbody -Headers $headers -Method Post).items
                $query = $null; $y = 0
            }
        }
    } while ($x -lt $contacts.Count)

    # Identify and enable missing client portal users
    if ($clientportal.Count -ne $contacts.Count) {
        Write-Host "Contacts: $($contacts.Count)"
        Write-Host "Enabled: $($clientportal.Count)"

        $missing = $contacts.id | Where-Object { $_ -notin $clientportal.contactId }

        foreach ($miss in $missing) {
            $contact = $contacts | Where-Object { $miss -eq $_.id }
            Write-Host "Enabling: $($contact.emailAddress)"

            $json = [PSObject]@{
                contactID            = $contact.id
                userName             = $contact.emailAddress
                securityLevel        = 1
                password             = (New-SecurePassword)
                numberFormat         = 22
                dateFormat           = 1
                timeFormat           = 1
                isClientPortalActive = $true
            } | ConvertTo-Json -Depth 10

            Start-Sleep -Milliseconds 10

            Invoke-RestMethod -Uri ($at_uri + '/v1.0/ClientPortalUsers') -Method POST -Body $json -Headers $headers
        }
    }
}
