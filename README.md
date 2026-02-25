<h1 align="center">AWS PowerShell Modules Updater & Synchronizer 🚀</h1>

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-%E2%89%A5%207.0-blue.svg" alt="PowerShell Version">
  <img src="https://img.shields.io/badge/Platform-Windows-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/AWS-Tools-FF9900.svg" alt="AWS Tools">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</p>

> An automated, smart utility script to keep your AWS PowerShell modules updated, synchronized, and clean across both PowerShell 7 (Core) and PowerShell 5.1 (Desktop) environments.

---

## 📖 Overview

Managing AWS PowerShell modules (`AWS.Tools.*`) across different PowerShell environments can lead to version mismatches and bloated folders with outdated files. 

This script solves that by acting as a centralized updater. It smartly checks for the latest AWS module versions, updates them in PowerShell 7, synchronizes the exact same versions back to PowerShell 5.1, and safely cleans up all legacy versions to free up disk space.

## ✨ Key Features

* **🔒 Auto-Elevation:** Automatically detects if it's running as Administrator and re-launches itself with elevated privileges if necessary.
* **🧠 Smart Updates:** Compares local module versions against the remote PowerShell Gallery to avoid redundant downloads.
* **🔄 Dual-Environment Sync:** Ensures that your PowerShell 5.1 environment has the exact same AWS module versions as your PowerShell 7 environment.
* **🧹 Background Cleanup:** Safely uninstalls and removes outdated module folders using a spawned background process to prevent file-locking conflicts.
* **📊 Detailed Reporting:** Provides a clean, colorful console output and a final summary table of all processed modules.

---

## ⚙️ Prerequisites

* **Operating System:** Windows
* **PowerShell:** Version 7.0 or higher (Required to run the script).
* **Permissions:** Administrator rights (The script will prompt for elevation automatically).
* **Internet Connection:** Required to reach the PowerShell Gallery.

---

## 🚀 Usage

1. Clone this repository or download the `Update-AWSModules.ps1` script.
2. Open your terminal.
3. Execute the script:

```powershell
.\Update-AWSModules.ps1
```
Note: If you are not running as an Administrator, a UAC prompt will appear to elevate the session.

🛠️ How It Works (The 3 Phases)
Phase 1: Smart Check & Update (PS7)

Iterates through a predefined list of AWS modules.

Checks the local version vs. the latest version on the PowerShell Gallery.

Installs or updates the module in the AllUsers scope if a newer version is found.

Phase 2: Synchronization & Cleanup Prep

Finds the newly updated modules in the PowerShell 7 directory.

Copies them to the Windows PowerShell 5.1 modules directory.

Scans for older versions of these modules and prepares commands to remove them safely.

Phase 3: Execution & Final Report

Spawns a new hidden PowerShell process to run the cleanup commands. This ensures that the current session doesn't lock the files being deleted.

Outputs a final, easy-to-read table showing the status of each module across both environments.

📝 Customization
You can easily add or remove specific AWS modules by editing the $awsModulesToManage array at the top of the script:

PowerShell
$awsModulesToManage = @(
    "AWS.Tools.Common",
    "AWS.Tools.EC2",
    "AWS.Tools.S3"
    # Add your required modules here
)
🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
