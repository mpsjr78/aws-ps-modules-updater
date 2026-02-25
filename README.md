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
