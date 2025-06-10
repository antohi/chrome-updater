# Chrome Auto Update PS Script

$time       = Get-Date -Format "yyyy-MM-dd HH:mm:ss" # <-- Sets time/date format for logging
$comp_name  = $env:COMPUTERNAME # <-- Stores name of the host being targeted
$log_file   = "C:\ProgramData\Chrome_Update_Log.txt" <-- Logs file in Chrome_Update_Log.txt

# Helper function for logging
function log { 
    param([string] $message) 
    Add-Content -Path $log_file -Value "[$time][$comp_name] $message" # <-- adds line with log text to Chrome_Update_Log.txt
}

log "Starting Chrome update for $comp_name" # <-- Logs the host name of target

# Locates chrome uninstall key, for both 64 bit and 32 bit versions
$uninstallRoots = @( 
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", # <-- 64 bit version
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" # <-- 32 bit version
)
$chromeKey = $null # <-- initally set to null until Chrome is found

# Loops thru each uninstall root
foreach ($root in $uninstallRoots) {  # For each object, tries to read the uninstall root
    $found = Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object { 
        try {
            $item = Get-ItemProperty $_.PSPath -ErrorAction Stop 
            if ($item.DisplayName -like "Google Chrome*") { # <-- If app name is Google Chrome, return the path
                return $_.PSPath
            }
        } catch {}
    }
    if ($found) { # <-- If chrome was found, chrome key is set to path
        $chromeKey = $found
        break
    }
}

if (-not $chromeKey) { # <-- If not found, logs it and stops process.
    log "Chrome uninstall registry key not found."
    exit 0
}

# Read installed version
try {
    $cur_version = (Get-ItemProperty $chromeKey -ErrorAction Stop).DisplayVersion # <-- Sets chrome version to variable
    log "Detected Chrome version: $cur_version" # <-- Logs version using variable
	
    $min_version = "200.0.0.0" # <-- Set the minimum version acceptable version for Chrome
    if ([version]$cur_version -ge [version]$min_version) { # If current version, is more than the min_version, log and don't update.
        log "Chrome already >= $min_version—no action needed." 
        exit 0
    } else {
        log "Chrome < $min_version—will update."
    }
} catch {
    log "ERROR reading version at $chromeKey—$_"
    exit 1
}

# Download Enterprise MSI Paths
$installer_url  = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
$installer_path = "$env:TEMP\ChromeEnterprise.msi"

try {
    Invoke-WebRequest -Uri $installer_url -OutFile $installer_path -ErrorAction Stop # Downloads installer
    log "Downloaded MSI to $installer_path" 
} catch {
    log "ERROR downloading MSI—$_" # Logs Error if download failed
    exit 1
}

# Silently install
try {
    Start-Process msiexec.exe -ArgumentList "/i `"$installer_path`" /qn /norestart" -Wait -ErrorAction Stop # <-- Installs chrome in the background, silently
    log "Silent install completed"
} catch {
    log "ERROR during install—$_"  # <-- Error logged if silent install fails
    exit 1
}

# Cleanup (Removes installer)
try {
    Remove-Item $installer_path -Force
    log "Installer cleaned up"
} catch {
    log "WARNING: Could not delete installer file"
}

log "Chrome update process complete."
