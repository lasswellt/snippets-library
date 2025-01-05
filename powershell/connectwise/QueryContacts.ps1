###########################################################
# File: QueryContacts.ps1
# Author: Tom Lasswell
# Email: lasswellt@gmail.com
# Website: https://lasswell.me
# Repository: https://github.com/lasswellt
#
# Description: This PowerShell script utilizes the ConnectWise
#              REST API to query for contacts based on a provided
#              email address. It supports wildcard searches and
#              processes results into a simplified JSON format.
#
# Notes:
#  - Authentication requires ConnectWise API public and private keys.
#  - Adjust email search logic as necessary for partial or domain-wide searches.
#  - Outputs results as a JSON file for further processing.
#
# Disclaimer: Use this script at your own risk. Ensure it
#              is tested in a development environment
#              before production use.
#
# PowerShell Help Info:
# .SYNOPSIS
#   Queries the ConnectWise REST API for contacts by email address.
# .DESCRIPTION
#   This script authenticates to the ConnectWise REST API and retrieves
#   contact information based on email addresses using wildcard support.
# .NOTES
#   File Name: QueryContacts.ps1
#   Author: Tom Lasswell
#   Email: lasswellt@gmail.com
#   Website: https://lasswell.me
#   Repository: https://github.com/lasswellt
# .EXAMPLE
#   .\QueryContacts.ps1 -req_query_email "example@domain.com"
#   Retrieves contact information for the provided email address.
###########################################################

# GET method: each querystring parameter is its own variable
if ($req_query_email) {
    $email = $req_query_email
}

###INITIALIZATIONS###
$global:CWcompany    = "company"
$global:CWprivate    = "privatekey"
$global:CWpublic     = "publickey"
$global:CWserver     = "https://api-na.myconnectwise.net"

###CW AUTH STRING###
[string]$Accept      = "Accept: application/vnd.connectwise.com+json; version=3.0"
[string]$Authstring  = $CWcompany + '+' + $CWpublic + ':' + $CWprivate
[string]$ContentType = 'application/json'
$encodedAuth         = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($Authstring)));

###CW HEADERS###
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Basic $encodedAuth")
$headers.Add("Content-Type", 'application/json')
$headers.Add("Accept", $Accept)

###CW QUERY###
[string]$TargetUri   = '/company/contacts'
[string]$query       = '?childconditions=communicationItems/value like "%' + $email + '%" AND communicationItems/communicationType="Email"'
[string]$BaseUri     = "$CWserver" + "/v4_6_release/apis/3.0" + $TargetUri + $query

###GET RESPONSE###
$JSONResponse = Invoke-RestMethod -URI $BaseUri -Headers $headers -ContentType $ContentType -Method Get

###PARSE CONTACT INFO TO USABLE SHORT TABLE###
$contactInfo = @()
foreach($contact in $JSONResponse) {
    $email = $null; $emails = $null
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name "id" -Value $contact.id
    $obj | Add-Member -MemberType NoteProperty -Name "firstName" -Value $contact.firstName
    $obj | Add-Member -MemberType NoteProperty -Name "lastName" -Value $contact.lastName
    foreach ($commtype in $contact.communicationItems) {
        $email = $($commtype | Where-Object {$_.communicationType -eq "Email"}).value
        if ($email.length -gt 2) { $emails += $email + ";" }
    }
    $obj | Add-Member -MemberType NoteProperty -Name "emails" -Value $emails
    $obj | Add-Member -MemberType NoteProperty -Name "company" -Value $contact.company.name
    $obj | Add-Member -MemberType NoteProperty -Name "companyid" -Value $contact.company.id
    $obj | Add-Member -MemberType NoteProperty -Name "companyidentifier" -Value $contact.company.identifier
    $contactInfo += $obj
}

If($contactInfo) {
    Out-File -Encoding Ascii -FilePath $res -InputObject $($contactInfo | ConvertTo-Json)
} Else {
    Return $False
}
