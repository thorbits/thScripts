<div align="center">
  <p>
    <img src="https://github.com/devicons/devicon/blob/master/icons/bash/bash-plain.svg" width="128" height="128">
  </p>
</div>
<div align="center">
  
# eZkde: Automated KDE 6 Installation Script
</div>
<div align="center">
  <p><br></p>
  
## User Manual
</div>

<div>
  <p><br></p>

eZkde is a shell script designed to automate the installation of a minimal KDE 6 desktop environment (Wayland session) with audio support (PipeWire) and essential utilities on a Debian-based Linux distribution. This script aims to provide a streamlined installation experience, especially for users new to KDE or looking for a quick setup.

## Prerequisites

*   A Debian-based Linux distribution (e.g., Debian, Ubuntu, Mint).
*   Administrative privileges (sudo or root access) are required to install packages and modify system configurations.
*   A stable internet connection for downloading packages and dependencies.

## Installation and Usage

1.  **Download the Script:**
    Download `ezkde_debian.sh` from: [GitHub](https://github.com/thorbits/thScripts/blob/main/ezkde_debian.sh).

2.  **Make the Script Executable:**
    Open a terminal and navigate to the directory where `ezkde_debian.sh` is located.  Run the following command:
    ```bash
    chmod +x ezkde_debian.sh
    ```

3.  **Run the Script:**
    Execute the script with root privileges:
    ```bash
    sudo ./ezkde_debian.sh
    ```

4.  **Follow On-Screen Prompts:**
    The script will display progress information and prompts during execution.  These prompts may include:
    *   Confirmation to proceed with the installation.
    *   Automatic components download.
    *   Progress of components intallation.

5.  **Reboot Your System:**
    After the installation is complete, the script will prompt you to reboot your system. Choose "yes" to reboot. The system will restart, and you should be greeted with the KDE 6 login screen (SDDM).

## Security Considerations

*   **Script Verification:**  Before running the script, verify its authenticity and integrity.  Check the GitHub repository for updates and reviews.
*   **Root Access:** Understand the implications of running a script with root access.  Only run scripts from trusted sources.

</div>

<div align="center">
  <p><br><br><br><br><br></p>
</div>

<div align="center">
  <p>
    <img src="https://github.com/devicons/devicon/blob/master/icons/bash/bash-plain.svg" width="128" height="128">
  </p>
</div>
<div align="center">
  
# eZkernel: Interactive Linux Kernel Compilation Script
</div>
<div align="center">
  <p><br></p>

## User Manual
</div>

<div>
  <p><br></p>

ezkernel is a semi-automated shell script designed for Debian-based systems to simplify the process of compiling and installing the latest Linux kernel from git.kernel.org. It aims to provide a user-friendly experience, automating key steps like source code download, dependency checking, and system configuration.

**⚠️ Important Disclaimer:** Compiling and installing a new kernel can be a complex process. While ezkernel strives to minimize risks, incorrect configuration or unforeseen errors can lead to system instability or a non-bootable system.  **Always create a system backup before proceeding.**

**Prerequisites:**

*   A Debian-based Linux distribution (e.g., Debian, Ubuntu, Mint).
*   Administrative privileges (sudo or root access).
*   A stable internet connection.
*   Approximately 20GB of free disk space.

**Installation and Usage:**

1.  **Download the Script:** Download `ezkernel_debian.sh` from [GitHub](https://github.com/thorbits/thScripts/blob/main/ezkernel_debian.sh).
2.  **Make the Script Executable:**
    Open a terminal and navigate to the directory where `ezkernel_debian.sh` is located.  Run the following command:
    ```bash
    chmod +x ezkernel_debian.sh
    ```

3.  **Run the Script:**
    Execute the script with root privileges:
    ```bash
    sudo ./ezkernel_debian.sh
    ```

4.  **Follow On-Screen Prompts:** The script will guide you through the process. You'll be prompted to:
    *   **Check Kernel Version:** The latest kernel version available will be displayed.
    *   **Confirm installation:**  This allows you to continue with the script.
    *   **Dependencies and sources:** The script will install necessary dependencies and then download the latest kernel sources.
    *   **Configuration:** Advanced users can customize the kernel configuration by modifying the `.config` file before compilation via menuconfig.
    *   **Compilation:**  The kernel will be compiled once you manually exit the configuration screen. This can take a significant amount of time depending on your system's hardware.
5.  **Reboot:**  After successful compilation, the script will prompt you to reboot your system.  Select "Yes" to reboot with the newly compiled kernel.

**Important Considerations:**

*   **Compilation:** The script is configured to utilize ALL available CPU threads during compilation time. Refer to the script's documentation or seek help from the online community if you encounter problems.
*   **Error Handling:** The script includes basic error handling, but be prepared to troubleshoot issues. Refer to the script's documentation or seek help from the online community if you encounter problems.
*   **Rollback:** If the new kernel causes problems, you can typically boot into your previous kernel using your bootloader's menu (e.g., Grub).   

</div>

<div align="center">
  <p><br><br><br><br><br></p>
</div>

<div align="center">
  <p>
    <img src="https://github.com/devicons/devicon/blob/master/fonts/devicon.svg" width="128" height="128">
  </p>
</div>
<div align="center">

## *About me*
</div>

<div align="center">
  <p><br>
  <img src="http://github-readme-streak-stats.herokuapp.com?user=thorbits&theme=transparent"/><br>
  <img src="https://github-readme-stats.vercel.app/api?username=thorbits&show_icons=true&theme=transparent&rank_icon=github"/><br>
  <img src="https://github-readme-stats.vercel.app/api/top-langs/?username=thorbits&layout=compact&theme=transparent"/><br>
  </p>
</div>

<div align="center">
  <p><br>
  <img src="https://img.shields.io/github/commit-activity/t/thorbits/thScripts">
  <img src="https://komarev.com/ghpvc/?username=thorbits&style=flat-square&color=blue" alt=""/>
  </p>
</div>

<div align="center">
  <p><br>
  <img src="https://img.shields.io/badge/LinkedIn-blue?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn Badge"/>
  <img src="https://img.shields.io/badge/YouTube-red?style=for-the-badge&logo=youtube&logoColor=white" alt="Youtube Badge"/>
  <img src="https://img.shields.io/badge/Twitter-blue?style=for-the-badge&logo=twitter&logoColor=white" alt="Twitter Badge"/>
  </p>
</div>

<div align="center">
  <p><br>
    
  ``Thanks for visiting!``
  
  </p>
</div>
