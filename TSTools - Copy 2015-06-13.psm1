
Import-Module PSTerminalServices
function get-TSSessionCount {
<#
.SYNOPSIS
 Counts the active and disconnected session for the supplied servers

. DESCRIPTION
 Counts the active and disconnected session for the supplied servers.  Excludes workstations called "Console" or "Service

.PARAMETER ComputerName
 The name of the serve(s) to count sessions

.EXAMPLE
 get-TSSessionCount dnvts01,dnvts02

  Displays each line as its calculated

                                 Active Server                                                             Disconnected
                                 ------ ------                                                             ------------
                                      2 dnvts01                                                                       0
                                      3 dnvts02                                                                       0


.EXAMPLE
 get-TSSessionCount dnvts01,dnvts02 | select Server,Active,Disconnected 

 Displays each line as its calculated

     Server                                                                   Active                            Disconnected
    ------                                                                   ------                            ------------
    dnvts01                                                                       2                                       0
    dnvts02                                                                       3                                       0


.EXAMPLE
 get-TSSessionCount dnvts01,dnvts02 | select Server,Active,Disconnected | ft -auto

 Nicer output but doesn't display until the whole lot is calculated. You can get a blow by blow list as its created if you use -verbose

     Server  Active Disconnected
    ------  ------ ------------
    dnvts01      2            0
    dnvts02      3            0

.EXAMPLE
 get-content ts-servers.txt | get-TSSessionCount dnvts01,dnvts02 | select Server,Active,Disconnected

 gets the count of all active and disconnected sessions of the servers listed in ts-servers.txt. This is included in the function: get-RDSFarmSessionCount

.LINK 
https://technet.microsoft.com/en-us/library/cc737077%28v=ws.10%29.aspx
 Link to "Viewing session states"

.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module
#>



    [cmdletBinding()]
    Param ([Parameter (
                Mandatory = $TRUE,
                HelpMessage = 'Computer Name',
                ValueFromPipeLine = $TRUE,
                ValueFromPipelineByPropertyName = $TRUE
                )]
            [string[]] $ComputerName
            )
    
    BEGIN{}
    

    PROCESS{

        ForEach ($server in $ComputerName) {
    
            $Connections = Get-TSSession -ComputerName $server -Filter { "Services","Console" -NotContains $_.WindowStationName -Contains $_.ConnectionState}
 
            $result = @{"Server" = $server;
                        "Active" = 0;
                        "Disconnected" = 0;
                        "Connected"=0;
                        "ConnectQuery" = 0;
                        "RemoteControl" = 0;
                        "Idle" = 0;
                        "Down"=0
                       }

           ForEach ( $conn in $Connections ) {
                switch($conn.ConnectionState) {
                    "Active" { $result.Active+= 1; break}
                    "Disconnected" {$result.Disconnected+= 1; break}
                    "Connected" {$result.Connected+= 1; break}
                    "ConnectQuery" {$result.ConnectQuery+= 1; break}
                    "RemoteControl" {$result.RemoteControl+= 1; break}
                    "Idle" {$result.Idle+= 1; break}
                    "Down" {$result.Down+= 1; break}
                } #switch
             } # foreach connection
    
            $obj = New-Object -TypeName PSObject -Property $result
            $obj.psobject.typenames.insert(0, 'sdhb.tstools.connectionstatus')

            write-verbose ("Server: {0},  Active: {1}, Disconnected: {2}, Connected: {3}" -f $obj.Server,$Obj.Active,$obj.disconnected,$obj.Connected)
            Write-Output $obj

        }#foreach server
    }

    END{}
}

function get-TSConnectionStatus{
<#
.SYNOPSIS
 Checks the connection status of a Terminal Server

. DESCRIPTION
 Checks the connection status of a Terminal Server

.PARAMETER ComputerName
The name(s) of the Terminal Server


.EXAMPLE
 get-TSConnectionStatus dnvts01

 ConnectionStatus                                            ComputerName
----------------                                            ------------
Enabled                                                     dnvts01

.EXAMPLE
 get-TSConnectionStatus dnvts01, dnvts02 | select ComputerName, Status | FT -auto

 ComputerName ConnectionStatus
------------ ----------------
dnvts01      Enabled
dnvts02      Enabled

.EXAMPLE
 get-content servers.txt | get-TSConnectionStatus
 
 Checks and displays the connection-status of each server listed in servers.txt

.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module

#>


    [cmdletBinding()]
     Param ([Parameter (
                Mandatory = $TRUE, 
                ValueFromPipeLine = $TRUE,
                ValueFromPipelineByPropertyName = $TRUE
                )]
                [string[]] $ComputerName
     )

     BEGIN{}

     PROCESS{
        ForEach ($Server in $ComputerName){

            $conn = Get-WmiObject -ComputerName $Server -Class win32_terminalservicesetting -Namespace "root\cimv2\terminalservices" 
            
            $prop = @{"ComputerName" = $Server;
                      "ConnectionStatus" = ""
                    }

            If ($conn.logons -eq 1){
                $prop.ConnectionStatus = "Disconnected"
            } Else {
                switch ($conn.sessionbrokerdrainmode){
                        0 {$prop.ConnectionStatus = "Enabled"}
                        1 {$prop.ConnectionStatus = "DrainUntilRestart"}
                        2 {$prop.ConnectionStatus = "Drain"}
                        default {$prop.ConnectionStatus = "Unknown/Error"
                    }
                }#switch
            } #else

            $obj = New-Object -TypeName PSObject -Property $prop
            $obj.psobject.typenames.insert(0, 'sdhb.tstools.tsstatus')
            write-verbose ("Server: {0} status:   {1}" -f $obj.Computername,$Obj.ConnectionStatus)
            Write-Output $obj
        } #foreach server
    }
    END{}
}

function get-TSConnectionDetails {

<#
.SYNOPSIS
 Gets the connection status and number of connections on a Term Server

. DESCRIPTION
 Calls and merges the results of both get-TSConnectionstatus and get-TSSessionCount.

.PARAMETER ComputerName
 The name of the computer(s) to check sessions and connections

.EXAMPLE
 get-TSConnectionDetails dnvts01

ConnectionStatus : Enabled
ComputerName     : dnvts01
Active           : 1
Connected        : 0
Disconnected     : 0

.EXAMPLE
 get-TSConnectionDetails dnvts01 | ft -auto

ConnectionStatus ComputerName Active Connected Disconnected
---------------- ------------ ------ --------- ------------
Enabled          dnvts01           1         0            0

.EXAMPLE
 get-TSConnectionDetails dnvts01 | select ComputerName, ConnectionStatus, Active, Disconnected, Connected | ft -auto

ComputerName ConnectionStatus Active Disconnected Connected
------------ ---------------- ------ ------------ ---------
dnvts01      Enabled               1            0         0

A version of this exists as a worker-function get-RDSFarmSummary which runs through all of the servers in RDSFarm1

.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module
#>


    [cmdletBinding()]
         Param ([Parameter (
                    Mandatory = $TRUE, 
                    ValueFromPipeLine = $TRUE,
                    ValueFromPipelineByPropertyName = $TRUE
                    )]
                    [string[]] $ComputerName
         )

     BEGIN{}
     PROCESS{
       
        ForEach ($Server in $ComputerName) {
            if (test-connection -computername $server -count 1 -quiet){
               # Write-Verbose "GET-TSConnectionDetails $Server"

                $status = get-TSConnectionstatus $Server
                $count = get-TSSessionCount $Server

                $prop = @{"ComputerName" = $Server;
                          "ConnectionStatus" = $status.ConnectionStatus;
                          "Active" = $count.active;
                          "Disconnected" = $count.disconnected
                          "Connected" = $count.Connected
                          }

            } else {
                Write-Verbose "!!!!!!!!! $server down"  
                $prop = @{"ComputerName" = $Server;
                          "ConnectionStatus" = "Cannot Ping";
                          "Active" = "-";
                          "Disconnected" = "-"
                          "Connected" = "-"
                          } 

            }#if-else test ping
            $obj = New-Object -TypeName PSObject -Property $prop
            $obj.psobject.typenames.insert(0, 'sdhb.tstools.tsConnectionDetails')
            Write-Output $obj
        } # foreach server
    } #process

    END{}
}


############# TSSession Worker Functions #############################
#
#  Simple functions pulling info from TSSession and formats them
#  Doesn't play well with the pipeline - use TSSession directly if that's
#  needed
#
######################################################################
function get-TSactiveSessions {
<#
.SYNOPSIS
 Gets basic info on active sessions for a single computer

.DESCRIPTION
 Gets basic info on active sessions for a computer - UserName, Computer Name, LoginTime, LastInputTime
 Doesn't take anything from pipeline. Displays as a table - not objects. If you want to use these objects then call TSSession instead
 

.EXAMPLE
get-TSactiveSessions dnvts01
That's it - just a single computer name

UserName     ClientName LoginTime           LastInputTime
--------     ---------- ---------           -------------
adminhcotago            9/03/2015 12:26:39
urgentdoc    RECEPT04   11/03/2015 07:55:48 11/03/2015 20:50:58
 
.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module
 
#>
    Param ([string] $ComputerName)
    Get-TSSession -ComputerName $ComputerName -State Active | 
        Select-Object UserName,clientname,LoginTime,LastInputTime | 
        Format-Table -AutoSize
}

function get-TSSessionTimes {
<#
.SYNOPSIS
 Gets basic time info on sessions for a single computer

.DESCRIPTION
 Gets basic time info of sessions on computer - username,clientname,connectionstate,ConnectTime,logintime,lastinputtime,IdleTime
 Doesn't take anything from pipeline. Displays as a table - not objects. If you want to use these objects then call TSSession instead
 

.EXAMPLE
get-TSSessionTimes dnvts01
That's it 

UserName     ClientName ConnectionState ConnectTime         LoginTime           LastInputTime       IdleTime
--------     ---------- --------------- -----------         ---------           -------------       --------
adminhcotago                     Active 9/03/2015 08:54:30  9/03/2015 12:26:39                      00:00:00
dnhmmh0      PC121044            Active 20/03/2015 16:53:24 20/03/2015 16:53:58 21/03/2015 06:23:18 00:53:39.9403066
dntzma0      A21160              Active 20/03/2015 15:59:49 20/03/2015 08:17:32 21/03/2015 04:44:54 02:32:04.2693891
 
.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module
  21/3/2015: daveb added all of the time fields
#>

[cmdletBinding()]
     Param ([Parameter (
                    Mandatory = $TRUE
                    )]
        [string] $ComputerName
     )
     write-verbose $ComputerName
    Get-TSSession -ComputerName $ComputerName | 
            where logintime -ne $null | 
            select username,clientname,connectionstate,ConnectTime,logintime,lastinputtime,IdleTime | 
            ft -auto
}


######################## RDSFarm Functions ####################################
#
# Functions which work with the details of the computers in $RDSFarm
#
###############################################################################

# List of servers in RDSFarm
$RDSFarm = get-content \\ldap\netlogon\ts-servers.txt


function get-RDSFarmSummary {
<#
.SYNOPSIS
 Worker-function  calling get-TSConnectionDetails for RDSFarm1

.DESCRIPTION
 This function calls get-TSConnectionDetails for the servers listed in \\ldap\netlogon\ts-servers.txt.  It performs a selection to order the output fields and a Format-Table to make the output a little nicer. There is a delay in display as format-table needs to collect all the data before displaying anything. You can get a server by server feedback with the -verbose flag

.EXAMPLE
 get-RDSFarmSummary

.EXAMPLE
 get-RDSFarmSummary -verbose

For each server gives verbose comments such as the following before displaying the full formated table

VERBOSE: Server: dnvts01 Status:   Enabled
VERBOSE: Server: dnvts01,  Active: 1, Disconnected: 0, Connected: 0

.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module
#>

    [CmdletBinding()]
    Param()
    $Tsdetail=@()
    $tot = $RDSFarm.count
    $counter=0
    foreach ($server in $RDSFarm) {
        $counter+=1
        $prog=[system.math]::round($counter/$tot*100,2)

        write-progress -activity "Scanning RDSFarm: $server" -status "$prog% Complete:" -percentcomplete $prog;
        $TSDetail += (get-TSConnectionDetails $server  | Select-Object ComputerName, ConnectionStatus, Active, Disconnected, Connected )
        } 
     $TSDetail | Format-Table -AutoSize        
}

function restart-RDSFarm {
<#
.SYNOPSIS
 Worker-function - Restarts servers on RDSFarm which are set to drainuntilrestart and have no active connections. Requires confirmation

.DESCRIPTION
 This function calls get-TSConnectionDetails for the servers listed in \\ldap\netlogon\ts-servers.txt.

 It checks the connection status for DrainUntilRestart and offers to restart any server with no active connections

 This function supports -whatif and -confirm. The imapct is set to high so a confirm is required by default

.EXAMPLE
 restart-RDSFarm
 Offers to restart all servers that are set to DrainUntilRestart that have no active connections

.EXAMPLE
 get-RDSFarmSummary -verbose

Displays connection status for every server as it goes through the list

.EXAMPLE
 restart-RDSFarm -confirm:$False

 Will not require confirmation - you'd better be sure.

.NOTES
 Author: Dave Bremer
 Updates:
  2/4/15: Added to module
#>

    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact='High')]
    Param()
    $Tsdetail=@()
    $tot = $RDSFarm.count
    $counter=0
    foreach ($server in $RDSFarm) {
            write-verbose "$server"
            $counter+=1
            $prog=[system.math]::round($counter/$tot*100,2)

            write-progress -activity "Scanning RDSFarm: $server" -status "$prog% Complete:" -percentcomplete $prog;
            $Tsdetail = (get-TSConnectionDetails $server  | Select-Object ComputerName, ConnectionStatus, Active, Disconnected, Connected )
            write-verbose $Tsdetail
            if ($Tsdetail.ConnectionStatus -eq "DrainUntilRestart" -and $Tsdetail.Active -eq 0) { 
                  #write-verbose "KILL KILL FILL $server"
                  
                  write-host ("`r`n`r`n{0}: Status {1}, Active {2}, Disconnected:{3}" -f $Tsdetail.ComputerName,$Tsdetail.ConnectionStatus,$Tsdetail.Active,$Tsdetail.Disconnected)
                  if ($pscmdlet.ShouldProcess(("Restarting {0}" -f $server))) {
                    restart-computer $server -force
                    } # whatif
                } #drainuntilrestart and empty
        } #foreach 
}


New-Alias ss-findsession get-RDSFarmSession 
function get-RDSFarmSession {

<#
.SYNOPSIS
 Finds a user session by checking through the servers in ts-servers.txt

.DESCRIPTION
 Reports back all connections - active or otherwise. 

The servers being checked are reported within a progress bar

The results are returned as they are received rather than waiting until the end.

.PARAMETER Client
The name of the computer used in a connection

.PARAMETER User
The username of the person to search

.PARAMETER Verbose
This is verbose help item

.EXAMPLE
 get-RDSFarmSession smszjg0
 
    ClientName             : PC141535
    ConnectTime            : 16/03/2015 08:21:10
    IdleTime               : 00:46:41.7655658
    Username               : smszjg0
    Server                 : dnvts01
    ID              : 11
    ServerConnectionStatus : Enabled
    ConnectionState        : Activex
    LastInputTime          : 17/03/2015 18:46:48
    DisconnectTime         :
    LoginTime              : 16/03/2015 08:21:45

.EXAMPLE
 get-RDSFarmSession -client PC141535

    ClientName             : PC141535
    ConnectTime            : 16/03/2015 08:21:10
    IdleTime               : 00:48:50.6774666
    Username               : smszjg0
    Server                 : dnvts01
    ID              : 11
    ServerConnectionStatus : Enabled
    ConnectionState        : Active
    LastInputTime          : 17/03/2015 18:46:48
    DisconnectTime         :
    LoginTime              : 16/03/2015 08:21:45

.NOTES
 Author: Dave Bremer
 Updates:
  16/3/15: Added to module

 Comments:
 Rewriting the functionality of Craig's ss-findsession.

#>

    [CmdletBinding(DefaultParametersetName="user")]
    Param(
        [Parameter (
                    ParameterSetName="client",
                    Mandatory = $TRUE
                    )]
                    [ValidateNotNullOrEmpty()]
                    [string]$client,
        
        [Parameter (
                    ParameterSetName="user",
                    Position=1,
                    Mandatory = $TRUE
                    )]
                    [ValidateNotNullOrEmpty()]
                    [string]$UserName

                   
        )

        

        #testing
        # $RDSFarm = "dnvts01","dnvts02", "dnvts32"

        $set = $PsCmdlet.ParameterSetName
        Write-Verbose "parameterSet is $set"

        switch($set){
            "user" {Write-Verbose "UserName: $UserName"}
            "client" {Write-Verbose "Client: $Client"}
        }
        
        $Tsdetail=@()
        $tot = $RDSFarm.count
        $counter=0
        foreach ($server in $RDSFarm) {
            $counter+=1
            $prog=[system.math]::round($counter/$tot*100,2)

            write-verbose "Prog = $prog"
            write-progress -activity "Searching RDSFarm: $server" -status "$prog% Complete:" -percentcomplete $prog;
            $result = $null           
            if (test-connection -computername $server -count 1 -quiet){
                Write-Verbose $server
                
                switch($set){
                    "user" {$result = (get-tssession -computername $server -UserName $username)}
                    "client" {$result = (get-tssession -computername $server -ClientName $client)}
                } #switch

                if ($result.count -ne 0) {
                    $status = get-TSConnectionStatus -ComputerName $server
                
                    $prop = @{
                                "Server" = $server;
                                "ServerConnectionStatus" = $status.ConnectionStatus;
                                "Username" = $result.UserName;
                                "ConnectionState" = $result.ConnectionState;
                                "ConnectTime" = $result.ConnectTime;
                                "LastInputTime" = $result.LastInputTime;
                                "DisconnectTime" = $result.DisconnectTime;
                                "LoginTime" = $result.LoginTime;
                                "IdleTime" = $result.IdleTime;
                                "ID" = $result.SessionID;
                                "ClientName" = $result.ClientName
                                }
                    $obj = New-Object -TypeName PSObject -Property $prop
                    $obj.psobject.typenames.insert(0, 'sdhb.tstools.RDSFarmUserSession')
                    Write-Output $obj
                }
            } else {
                Write-Verbose "$server down"
            }#if-else test ping
            
        } #foreach server
}

New-Alias ss-endsession stop-RDSFarmSession
function stop-RDSFarmSession {
<#
.SYNOPSIS
 Finds a user session by checking get-RDSFarmSession, then offers to end the session.

.DESCRIPTION
Finds all terminal server sessions with user name/asset number matching a string, then asks whether to terminate each session

.PARAMETER User
The username of the person to search

.EXAMPLE
 Stop-RDSFarmSession dndzbj0
 Searches for a user session of dndzbj0 and offers to end session

.EXAMPLE
 Stop-RDSFarmSession -client a21120
 Searches for a session with a client of a21120 and offers to end the session

.NOTES
 Author: Craig Raynor - wrote ss-endsession
 Date: Feb 2013
 Updates:
  16/3/15: Daveb - Added to module
  20/3/2015: Daveb - rewriting ss-findsession to match powershell's verb name and make use of other powershell features. 
  Replacing write-host with progress bar


#>
    [CmdletBinding(DefaultParametersetName="user")]
    Param(
        [Parameter (
                    ParameterSetName="client",
                    Mandatory = $TRUE
                    )]
                    [ValidateNotNullOrEmpty()]
                    [string]$client,
        
        [Parameter (
                    ParameterSetName="user",
                    Position=1,
                    Mandatory = $TRUE
                    )]
                    [ValidateNotNullOrEmpty()]
                    [string]$UserName          
        )
   
    $set = $PsCmdlet.ParameterSetName
        Write-Verbose "parameterSet is $set"

        switch($set){
            "user" { Write-Verbose "UserName: $UserName"
                    $sessions = get-RDSFarmSession -UserName $UserName
                    }
            "client" { Write-Verbose "Client: $Client"
                       $sessions = get-RDSFarmSession -Client $Client}
        }
   # $sessions = ss-findsession $user -all
   

   foreach ($s in $sessions)
   {
      if (!$s.server -or !$s.ID) {continue} #not sure why Craig had this - not keen to take out and break something

      $answer = read-host ("OK to logoff {0} on asset no. {1} from {2}? Type YES to confirm" -f $s.username, $s.clientname, $s.server)
      
      
      if ($answer -eq "YES"){
         write-host ("Ending ({0}/{1})..." -f $s.UserName, $s.ClientName) -foregroundcolor green
         stop-tssession -computername $s.server -id $s.ID -force      
      } else {
         write-host ("Skipping ({0}/{1})..." -f $s.UserName, $s.ClientName) -foregroundcolor red
      }   
   }
}

New-Alias ss-endproc stop-RDSFarmProc
function stop-RDSFarmProc {
<#
.SYNOPSIS
 Finds a user session by checking get-RDSFarmSession, then offers to end the specified procedure.

.DESCRIPTION
Finds all terminal server sessions with user name/asset number matching a string, then asks whether to terminate all processes with a particular name.

.PARAMETER UserName
Specifies the user name or asset number. May include wildcards.

.PARAMETER Proc
Specifies the process name. May include wildcards.

.NOTES
 Author: Craig Raynor - Feb 2013 - wrote ss-endproc
 Updates:
    20/3/15: DaveB Reformated as a standard powershell function
 
#>
 
     [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $TRUE,
                    Position = 1,
                    HelpMessage = 'Enter Username')]
                    [ValidateNotNullOrEmpty()]
                    [string]$Username,
        
        [Parameter (Mandatory = $TRUE,
                    Position = 2,
                    HelpMessage = 'Enter Process Name')]
                    [ValidateNotNullOrEmpty()]
                    [string]$Proc          
        )

   <#if (!$user -or !$proc){
      write-host "You must enter both a user name/asset no. and process name" -foregroundcolor yellow
      write-host "E.g. ss-endproc -user dnczra0 -proc winword.exe" -foregroundcolor yellow
      return
   }#>

   $sessions = get-RDSFarmSession $Username
   

   foreach ($s in $sessions)
   {
      if (!$s.server -or !$s.id) {continue} # is this really necessary?
      
      $numprocs = (get-tssession -computername $s.server -id $s.id| get-tsprocess | ? {$_.processname -like $proc} | measure).count
      
      if ($numprocs -eq 0) {continue}

      $answer = read-host ("OK to end {0} for {1} (asset no. {2} on {3})? Type YES to confirm" -f $proc, $s.username, $s.clientname, $s.server)
      
      if ($answer -eq "YES") {
         write-host ("Ending {0}..." -f $proc) -foregroundcolor green
         Stop-TSProcess -ComputerName $s.server -Name $proc -force
      } else {
         write-host "Skipping" -foregroundcolor red
      }   
   }
}





Export-ModuleMember -Function * -Alias * -Variable *