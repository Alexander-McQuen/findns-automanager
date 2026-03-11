🚀 Findns Auto-Manager & Ultimate Scanner
An interactive, all-in-one management tool for Findns. This script automates the process of installing, configuring, and running a continuous background scanner to find working resolvers for your DNSTT tunnels.

✨ Features
One-Click Setup: Automatically installs Go, Git, Screen, and builds the findns and dnstt-client binaries.

Background Scanning: Runs the scanner in a screen session so it keeps working even after you disconnect from SSH.

Smart Result Management: Collects working resolvers into a clean file, automatically removes duplicates, and sorts them.

Interactive Menu: No need to remember long commands. Manage everything through a simple numbered menu.

Resource Optimized: Uses nice to ensure the scanner doesn't slow down your VPS or other services like 3x-ui.

⚡ Quick Installation
Run this single command on your fresh Ubuntu/Debian server to get started:

```bash
bash <(curl -Ls [https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO_NAME/main/install.sh](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO_NAME/main/install.sh))
```


🛠 How to Use
Once the menu opens, follow these simple steps:

Select 1 (Full Setup): This will prepare your server and build all necessary files.

Select 2 (Set Config): Enter your DNSTT Domain and Public Key.

Select 3 (Start Scanner): The engine will start searching for resolvers in the background.

Select 4 (View Results): Check this periodically to see your list of working resolvers.

📋 Requirements
OS: Ubuntu 20.04 or newer (Recommended).

User: Root access or sudo privileges.

Resources: At least 512MB RAM.

🤝 Credits
This manager is a wrapper for the excellent findns tool by SamNet-dev.
