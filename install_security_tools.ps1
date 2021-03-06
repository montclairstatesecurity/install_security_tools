<# 
.SYNOPSIS
    Installs security tools on Windows servers

.DESCRIPTION
    Installs ISIM security tools on a Windows server when invoked, including: Bit9 Parity, Sysmon, Sophos AV, Graylog Collector Sidecar

.EXAMPLE
    ./Install-SecurityTools.ps1

.NOTES
    This script must be run as a user that is a member of the local Administrators group on the system

.LINK
    https://security.montclair.edu
#>


# installing Parity with monitor policy
############################################
function install-parity {

    # Don't run the function if Parity is already installed
    if (Test-Path "C:\Program Files (x86)\Bit9\Parity Agent\Parity.exe") {
        return
    }
    
    msiexec.exe /i "\\msufiles.admsu.montclair.edu\winserverdeploy\isim\bit9\monitor.msi" /norestart /qn | Out-Null
}
 
# installing sysmon and configuration files
############################################

function install-sysmon {
    
    # Don't run the function if Sysmon is already installed
    if (Test-Path "C:\Windows\Sysmon.exe") {
        return
    }
    
    \\msufiles.admsu.montclair.edu\winserverdeploy\isim\sysmon\sysmon64.exe -accepteula –i | Out-Null
    sysmon -c \\msufiles.admsu.montclair.edu\winserverdeploy\isim\sysmon\sysmonconfig-export-modified.xml | Out-Null
}

# installing sophos and configuration files
############################################

function install-sophos {
    
    # Don't run the function if Sophos is already installed
    if (Test-Path "C:\Program Files\Sophos\AutoUpdate\ALsvc.exe"){
        return
    }
    if (Test-Path "C:\Program Files (x86)\Sophos\AutoUpdate\ALSVC.exe") {
        return
    }
    if (Test-Path "C:\Documents and Settings\All Users\Application Data\Sophos\Remote Management System\3\Agent\AdapterStorage\SAV\SAVAdapterConfig") {
        return
    }
    if (Test-Path "C:\ProgramData\Sophos\Remote Management System\3\Agent\AdapterStorage\SAV\SAVAdapterConfig" ) {
        return
    }

    # Deploy, with a default group of ETS
    \\sophos.montclair.edu\SophosUpdate\CIDs\S081\SAVSCFXP\Setup.exe -mng yes -updp http://avupdates.montclair.edu/CIDs/S081/SAVSCFXP/ -G "\sophos\ETS" -s -ni | Out-Null  
     
    # This step should not be necessary once firewall rules are managed centrally in AD via GPO
    if (Get-NetFirewallRule -DisplayName "Sophos RMS Inbound" -ErrorAction SilentlyContinue) {
        return
    }
    else {
        New-NetFirewallRule -DisplayName "Sophos RMS Inbound" -RemoteAddress 130.68.1.193 -Protocol TCP -LocalPort 8192,8193,8194 -Profile private,public,domain  | Out-Null
    }
}

# installing graylog and configuration files
############################################

function install-graylog {

    # Let's initialize some variables
    $computername=$env:computername

    # Don't run the installer if the program is already present
    if (Test-Path "C:\Program Files\Graylog\collector-sidecar\uninstall.exe") {
        return
    }
        
    # Run the installer
    & "\\msufiles.admsu.montclair.edu\winserverdeploy\isim\graylog\collector_sidecar_installer_0.1.0.exe" "/S"
    
    # Determine if the IP address of the host is public or private and copy in the correct collector_sidecar.yml file based on that

    Get-WmiObject win32_networkadapterconfiguration -filter "ipenabled = 'True'" -ComputerName $computername |
    Select IPAddress |
    ForEach-Object {
       if ($_.IPAddress -like "130.68.*") {
            "Host is on 130.68. network"
            copy "\\msufiles.admsu.montclair.edu\winserverdeploy\isim\graylog\collector_sidecar_windows.yml" "C:\Program Files\Graylog\collector-sidecar\collector_sidecar.yml" | Out-Null
       }
       elseif ($_.IPAddress -like "10.*"){
            "Host is on 10. network"
            copy "\\msufiles.admsu.montclair.edu\winserverdeploy\isim\graylog\collector_sidecar_windowsdc.yml" "C:\Program Files\Graylog\collector-sidecar\collector_sidecar.yml" | Out-Null
       }
    }
         
    # Install and start the collector-sidecar service

    & "C:\Program Files\Graylog\collector-sidecar\Graylog-collector-sidecar.exe" "-service" "install" | Out-Null
    & "C:\Program Files\Graylog\collector-sidecar\Graylog-collector-sidecar.exe" "-service" "start" | Out-Null

}

# MAIN
# just call the functions we've created
#######################################

"Installing Bit9 Parity..."
install-parity

"Installing Sysmon..."
install-sysmon

"Installing Sophos AV..."
install-sophos

"Installing Graylog collector..."
install-graylog

"Complete!"