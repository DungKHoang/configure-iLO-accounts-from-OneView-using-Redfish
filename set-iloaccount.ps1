## -------------------------------------------------------------------------------------------------------------
##
##
##      Description: OneView-iLO functions
##
## DISCLAIMER
## The sample scripts are not supported under any HPE standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind. 
## HP further disclaims all implied warranties including, without limitation, any implied 
## warranties of merchantability or of fitness for a particular purpose. 
##
##    
## Scenario
##     	Use SSO to configure iLO from OneView
##		
##
## Input parameters:
##         OVApplianceIP                      = IP address of the OV appliance
##		   OVAdminName                        = Administrator name of the appliance
##         OVAdminPassword                    = Administrator's password
##         iLOUserCSV                         = path to the CSV file containing user accounts definition
##
## History: 
##
##          February-2016   : v1.0
##          October - 2019: v2.0
##
## Version : 2.0
##
##
## -------------------------------------------------------------------------------------------------------------

Param ( [string]$OVApplianceIP      = "192.168.1.51", 
        [string]$OVAdminName        = "administrator", 
        [string]$OVAdminPassword    = "password",
        [string]$OneViewModule      = "HPOneView.420",  
        [string]$RedFishModule      = "HPERedfishCmdlets", 
        [string]$OVAuthDomain       = "local",

        [string]$iLOAccountCSV  	= "iloAccount.csv"

)



## -------------------------------------------------------------------------------------------------------------
##
##                     Function Update-iLOAccount
##
## -------------------------------------------------------------------------------------------------------------

Function Update-iLOAccount 
{

Param ([string]$iLOAccountCSV ="")

    if ( -not (Test-path $iLOAccountCSV))
    {
        write-host "No file specified or file $iLOAccountCSV does not exist. Skip creating iLO account"
        return
    }
    # Read the CSV Users file
    $tempFile = [IO.Path]::GetTempFileName()
    type $iLOAccountCSV | where { ($_ -notlike ",,,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line

    $ListofAccts    = import-csv $tempfile 
  
    foreach ($A in $ListofAccts)
    {
        $accountName        = $A.accountName        # This is the user account name 
        $ServerName         = $A.ServerName

        if (($accountName -eq "") -or ($ServerName -eq ""))
        {
            write-host -ForegroundColor Yellow "No username specified or No Server HArdware specified. Skip modifying  accounts..."
            
        }

        else
        {
            $newPassword        = $A.newPassword
            $newAccountName     = $A.newAccountName
            $newloginName       = $A.newloginName
            $privList           = if ($A.privileges) { $($A.privileges).split('|')} else { ""}


            # Privileges
            $priv = @{}
            if ($privList)
            {
                foreach ($p in $privList)
                {
                    switch ($p.tolower())
                    {
                        'loginpriv'                 {     $priv.Add('LoginPriv',$true)                  }
                        'remoteconsolepriv'         {     $priv.Add('RemoteConsolePriv',$true)          }
                        'userconfigpriv'            {     $priv.Add('UserConfigPriv', $true)            }
                        'virtualmediapriv'          {     $priv.Add('VirtualMediaPriv',$true)           }
                        'virtualpowerandresetpriv'  {     $priv.Add('VirtualPowerAndResetPriv',$true)   }
                        'iloconfigpriv'             {     $priv.Add('iLOConfigPriv',$true)              }
                        'hostbiosconfig'            {     $priv.Add('HostBIOSConfigPriv',$true)         }
                        'hostnicconfigpriv'         {     $priv.Add('HostNICConfigPriv',$true)          }
                        'hoststorageconfigpriv'     {     $priv.Add('HostStorageConfigPriv',$true)      } 
                        'systemrecoveryconfigpriv'  {     $priv.Add('SystemRecoveryConfigPriv',$true)   }
                    }
                }
            }            
           
            
            ## ---- Get Server Hardware
            $ThisServer         = get-hpovServer | where name -eq $ServerName
            if ($ThisServer)
            {
                $iloSession     = $ThisServer | Get-HPOVIloSso -IloRestSession
        
                $rootURI        = $iloSession.rootUri
                $acctUri        = '/redfish/v1/AccountService/accounts/' 

    
                # get the odataid of the iLO user accounts
                $accData        = Get-HPERedfishDataRaw -odataid $acctUri  -Session $iloSession -DisableCertificateAuthentication
                $accOdataId     = $accData.Members.'@odata.id'
                


                foreach ($ac in $accOdataId )
                {

                    $accountDetails     = Get-HPERedfishDataRaw -odataid $ac -Session $iloSession -DisableCertificateAuthentication
                    $thisAccount        = $accountDetails.oem.hpe.LoginName
 

                        # check if user is present in the user list
                        if($thisAccount -eq $accountName)
                        {
                            $requiredAccountOdataId = $ac 
                         
                            # LoginName is known as user Account name
                            
                            $hpe = @{}
                            if ($newAccountName) { $hpe.Add('LoginName',$newAccountName) }
                            if ($priv)           { $hpe.Add('Privileges',$priv) }
                            
                            $oem = @{}
                            if ($hpe)            { $oem.Add('Hpe',$hpe) }

                            # --- UserName here is loginName
                            $user = @{}
                            if ($newLoginName)  { $user.Add("UserName" , $newLoginName) }                            
                            if ($newPassword)   { $user.Add("Password" , $newPassword)  } 
                            if ($oem)           { $user.Add('Oem',$oem) }

 
                            write-host -ForegroundColor Cyan "-----------------------------------------------------"
                            write-host -ForegroundColor Cyan "Changing attributes of account $accountName on ILO $iLOIP.... "
                            write-host -ForegroundColor Cyan "-----------------------------------------------------"

                            # PATCH data to change password
                            if ($user)
                            {
                                $ret    = Set-HPERedfishData -odataid $requiredAccountOdataId -Setting $user -Session $iloSession -DisableCertificateAuthentication
                                if($ret.error.'@Message.ExtendedInfo'.Count -gt 0)
                                {
                                    foreach($msgID in $ret.error.'@Message.ExtendedInfo')
                                    {
                                        $status = Get-HPERedfishMessage -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $iloSession -DisableCertificateAuthentication
                                        $status
                                    }
                                }
                            }

            
                        }
                    
                    
                }   
            }
            else
            {
                write-host -foreground Yellow "Server Hardware --> $ServerName is not managed by this OneView appliance. Skip creating accounts in iLO"
            }
            

        } #end else username empty
              
    }

}

## -------------------------------------------------------------------------------------------------------------
##
##                     Main Entry
##
## -------------------------------------------------------------------------------------------------------------


       # -----------------------------------
       #    Always reload module
   
       $LoadedModule = get-module -listavailable $OneviewModule


       if ($LoadedModule -ne $NULL)
       {
            $LoadedModule = $LoadedModule.Name.Split('.')[0] + "*"
            remove-module $LoadedModule
       }

       import-module $OneViewModule

       # ----------------------------------------
       # Import HPREdFish Cmdlets module
       $LoadedModule = get-module -listavailable $RedfishModule


       if ($LoadedModule -ne $NULL)
       {
            $LoadedModule = $LoadedModule.Name.Split('.')[0] + "*"
            remove-module $LoadedModule
       }

       import-module $RedFishModule

            # ---------------- Connect to OneView appliance
            #
            write-host -ForegroundColor Cyan "-----------------------------------------------------"
            write-host -ForegroundColor Cyan "Connect to the OneView appliance..."
            write-host -ForegroundColor Cyan "-----------------------------------------------------"
            Connect-HPOVMgmt -appliance $OVApplianceIP -user $OVAdminName -password $OVAdminPassword

            if ( ! [string]::IsNullOrEmpty($iLOAccountCSV) -and (Test-path $iLOAccountCSV) )
            {
                Update-iLOAccount -iLOAccountCSV $iLOAccountCSV 
            }



            write-host -ForegroundColor Cyan "-----------------------------------------------------"
            write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
            write-host -ForegroundColor Cyan "-----------------------------------------------------"
            
            Disconnect-HPOVMgmt
