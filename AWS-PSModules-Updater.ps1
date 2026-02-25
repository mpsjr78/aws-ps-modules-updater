<#
.SYNOPSIS
    AWS PowerShell Modules Updater & Synchronizer

.DESCRIPTION
    This script automates the update, synchronization, and cleanup of specific AWS.Tools 
    modules across both PowerShell 7 (Core) and PowerShell 5.1 (Desktop) environments.
    
    Workflow:
    1. Validates execution requirements (Administrator privileges and PowerShell 7+).
    2. Phase 1: Checks for updates for defined AWS modules and installs them in PS7.
    3. Phase 2: Synchronizes the latest installed versions to the PS5 module path.
    4. Phase 3: Identifies and safely removes outdated module versions in both environments 
       using a background process to avoid file locking issues.

.NOTES
    Author: Milton P. Silva Junior
    Date: February 2025
    Requirements: Requires PowerShell 7 or higher and Administrator elevation.
#>

[CmdletBinding()]
param()

# --- Administrator Check ---
if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "⚠️ This script must be run as an Administrator. Restarting with elevated privileges..."
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "pwsh.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Exit
}

#region CONFIGURATION AND INITIAL CHECKS
# Ensure the script stops on errors
$ErrorActionPreference = 'Stop'

# List of AWS.Tools modules to manage. Add or remove modules as needed.
$awsModulesToManage = @(
    "AWS.Tools.Common",
    "AWS.Tools.EC2",
    "AWS.Tools.RDS",
    "AWS.Tools.IdentityManagement",
    "AWS.Tools.Route53",
    "AWS.Tools.S3",
    "AWS.Tools.SecurityToken",
    "AWS.Tools.SimpleNotificationService",
    "AWS.Tools.SimpleSystemsManagement",
    "AWS.Tools.CloudWatch"
)

# Add legacy modules to ensure they are completely cleaned up if they exist.
$allModulesForCleanup = $awsModulesToManage + "AWSPowerShell", "AWSPowerShell.NetCore"

# --- PowerShell Version Check ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "❌ This script is designed to run on PowerShell 7 or higher."
    Read-Host "Press Enter to exit."
    Exit
}

# --- Module Paths Definition ---
$ps7ModulePath = $env:PSModulePath.Split(';') | Where-Object { $_ -match "Program Files[\\/]PowerShell[\\/]7[\\/]Modules" -or $_ -match "Program Files[\\/]PowerShell[\\/]Modules" } | Select-Object -First 1
$ps5ModulePath = $env:PSModulePath.Split(';') | Where-Object { $_ -match "WindowsPowerShell[\\/]Modules" } | Select-Object -First 1

if (-not $ps7ModulePath) { $ps7ModulePath = "C:\Program Files\PowerShell\7\Modules" }
if (-not $ps5ModulePath) { $ps5ModulePath = "C:\Program Files\WindowsPowerShell\Modules" }

Write-Host "✅ Initial checks completed."
Write-Host "   - PowerShell 7 Path: $ps7ModulePath" -ForegroundColor Gray
Write-Host "   - PowerShell 5 Path: $ps5ModulePath" -ForegroundColor Gray
Write-Host "-------------------------------------------------------------"
#endregion

#region PHASE 1: SMART CHECK AND UPDATE IN POWERSHELL 7

Write-Host "`n[Phase 1] Checking and updating modules in PowerShell 7..." -ForegroundColor Cyan

foreach ($moduleName in $awsModulesToManage) {
    Write-Host "   -> Processing: $moduleName"
    $needsUpdate = $true # Assumes update is needed by default

    try {
        $localModule = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        $remoteModule = Find-Module -Name $moduleName -ErrorAction Stop
        
        if ($null -ne $localModule -and $localModule.Version -ge $remoteModule.Version) {
            Write-Host "      ✅ Already at the latest version ($($localModule.Version))." -ForegroundColor Green
            $needsUpdate = $false
        } else {
            $localVersionString = if ($localModule) { $localModule.Version } else { "Not installed" }
            Write-Host "      -> Update required. Local: v$localVersionString, Remote: v$($remoteModule.Version)"
        }
    }
    catch {
        Write-Warning "      ⚠️ Unable to verify the remote version. The script will attempt the update as a fallback."
    }

    if ($needsUpdate) {
        try {
            Write-Host "      -> Running Install-Module for $moduleName..."
            Install-Module -Name $moduleName -Scope AllUsers -Force -AllowClobber -ErrorAction Stop
            Write-Host "      ✅ $moduleName successfully installed/updated." -ForegroundColor Green
        }
        catch {
            Write-Warning "      ⚠️ Failed to install/update the module $moduleName. Error: $($_.Exception.Message)"
        }
    }
}

Write-Host "-------------------------------------------------------------"
#endregion

#region PHASE 2: SYNCHRONIZATION AND CLEANUP PREPARATION

Write-Host "`n[Phase 2] Synchronizing with PS5 and preparing cleanup..." -ForegroundColor Cyan

$cleanupCommands = [System.Collections.Generic.List[string]]::new()
$finalReport = [System.Collections.Generic.List[object]]::new()

foreach ($moduleName in $awsModulesToManage) {
    $latestModule = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $latestModule) {
        Write-Warning "   -> ⚠️ Could not find the latest version of $moduleName after installation. Skipping."
        continue
    }

    $latestVersion = $latestModule.Version.ToString()
    $latestPathInPs7 = $latestModule.ModuleBase
    Write-Host "   -> Module [$moduleName]: Final version is $latestVersion"

    # --- Sincronization with PowerShell 5 ---
    $ps5DestinationPath = Join-Path -Path $ps5ModulePath -ChildPath "$moduleName\$latestVersion"
    $ps5ModuleExists = Test-Path $ps5DestinationPath

    if (-not $ps5ModuleExists) {
        Write-Host "      -> Copying $moduleName v$latestVersion to PowerShell 5..."
        try {
            Copy-Item -Path $latestPathInPs7 -Destination $ps5DestinationPath -Recurse -Force -ErrorAction Stop
            Write-Host "      -> Copy to PS5 completed." -ForegroundColor Green
            $ps5Status = "Synchronized"
        } catch {
            Write-Warning "      -> ⚠️ Failed to copy $moduleName to PS5. Error: $($_.Exception.Message)"
            $ps5Status = "Sync Failed"
        }
    } else {
        $ps5Status = "Already Existed"
    }

    # --- Old Versions Cleanup Preparation for PS5 ---
    $modulePathInPs5 = Join-Path -Path $ps5ModulePath -ChildPath $moduleName
    if (Test-Path $modulePathInPs5) {
        Get-ChildItem -Path $modulePathInPs5 -Directory | ForEach-Object {
            # Compares the folder name (which is the version) with the latest version we determined
            if ($_.Name -ne $latestVersion) {
                Write-Host "      -> Scheduling removal (PS5): $($moduleName) v$($_.Name)" -ForegroundColor Yellow
                # Adds the direct folder removal command to the cleanup list
                $cleanupCommands.Add("Remove-Item -Path '$($_.FullName)' -Recurse -Force -ErrorAction SilentlyContinue")
            }
        }
    }

    $finalReport.Add([PSCustomObject]@{ Module = $moduleName; FinalVersion = $latestVersion; PS7_Status = "Updated"; PS5_Status = $ps5Status })
}

# --- General Cleanup Preparation (using Uninstall-Module) ---
Write-Host "`n   -> Identifying versions managed by Package Manager for removal..."
foreach ($moduleName in $allModulesForCleanup) {
    $installedVersions = Get-InstalledModule -Name $moduleName -AllVersions -ErrorAction SilentlyContinue
    if ($installedVersions.Count -gt 1) {
        $latestVersionObj = $installedVersions | Sort-Object -Property {[version]$_.Version} -Descending | Select-Object -First 1
        $oldVersions = $installedVersions | Where-Object { $_.Version -ne $latestVersionObj.Version }
        
        foreach ($oldVersion in $oldVersions) {
            Write-Host "      -> Scheduling removal (General): $($oldVersion.Name) v$($oldVersion.Version)" -ForegroundColor Yellow
            $command = "Uninstall-Module -Name '$($oldVersion.Name)' -RequiredVersion '$($oldVersion.Version)' -Force -ErrorAction SilentlyContinue"
            $cleanupCommands.Add($command)
        }
    }
}
Write-Host "-------------------------------------------------------------"
#endregion

#region PHASE 3: CLEANUP EXECUTION

if ($cleanupCommands.Count -gt 0) {
    Write-Host "`n[Phase 3] Executing cleanup of old versions in a new process..." -ForegroundColor Cyan
    
    # Remove any duplicate commands that might have been generated
    $uniqueCommands = $cleanupCommands | Sort-Object -Unique
    $fullCommand = $uniqueCommands -join '; '
    $fullCommand += "; Write-Host '✅ Cleanup completed. This window will close in 5 seconds.' -ForegroundColor Green; Start-Sleep -Seconds 5"

    $psiCleanup = [System.Diagnostics.ProcessStartInfo]::new()
    $psiCleanup.FileName = "pwsh.exe"
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($fullCommand))
    $psiCleanup.Arguments = "-NoProfile -EncodedCommand $encodedCommand"
    $psiCleanup.Verb = "runas"
    
    $process = [System.Diagnostics.Process]::Start($psiCleanup)
    Write-Host "   -> Cleanup process initiated (PID: $($process.Id)). Waiting for completion..."
    $process.WaitForExit()
    Write-Host "   -> Cleanup process finished."
} else {
    Write-Host "`n[Phase 3] No old versions found to clean up." -ForegroundColor Green
}
Write-Host "-------------------------------------------------------------"
#endregion

#region FINAL REPORT

Write-Host "`n🎉 Update and synchronization process completed! 🎉`n" -ForegroundColor Green
Write-Host "Final Module Status Report:" -ForegroundColor Cyan
$finalReport | Format-Table -AutoSize

Write-Host "`nTo verify manually, use the command: Get-Module -Name AWS.Tools* -ListAvailable | Select-Object Name,Version,ModuleBase | Sort-Object Name,Version"
#endregion
