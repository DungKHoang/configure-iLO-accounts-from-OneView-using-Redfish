

# Configuring iLO accounts from OneView using RedFish

The script updates iLO accounts from OneView leveraging the single-sign-on experience and RedFish API

## Prerequisites
The  script requires":
   * the latest OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * HPERESTcmdlets cmdlets found on PowerShell gallery. 

## Environment

Your OneView environment should be at least at 4.00 level.
The script works only against iLO5 using RedFish

The iloaccount.csv contains the follwoign fields:
   * the server name 
   * accountName - current iLO account
   * newAccountName - new iLO account
   * newLoginName - new name for login
   * privileges  - list of privileges to be added 
   Use the iLOaccount.csv as an example 



## Syntax

### To change  ilo accounts

```
    .\Set-iLOaccount.ps1 -OVApplianceIP <OV-IP-Address> -OVAdminName <Admin-name> -OVAdminPassword <password> -iLOaccountCSV iloaccount.csv

```
