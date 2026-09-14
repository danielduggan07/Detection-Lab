# Day 1:
- Phase 1:

- Confirmed VT-x enabled, set up GitHub repo and cloned into VS Code

- Installed VirtualBox. This is because this project needs 3 separate "computers", a Domain Controller, a Windows client, and a Splunk server, all networked together. Also, safety is a reason. I plan on running an actual password-spray attack tool, and I don't want that running on my real everyday laptop. 

- Downloaded Windows Server. This is the operating system that will run inside my DC01 VM. It's the "brain" of my mini network. It's the OS that's capable of being promoted into a Domain Controller: a server that manages user accounts, logins, and security policy for every other machine that joins its domain. Windows 11 can't do this, only Windows Server can run Active Directory. I'm using the evaluation version because its a free trial for 180 days. This is needed because the password spray attack targets accounts on this domain controller. Without it, theres no domain, no test accounts, no realistic AD logs to detect anything in. 

- Downloaded Windows 11. This is what runs inside my CLIENT01 VM. It's the "employee workstation" of my mini network. In a real company, this would represent someones actual laptop/desktop thats joined to the company domain. This matters because this is the VM where the actual attack gets launched from, aiming at the test accounts sitting on DC01. It's also where I'll do my baseline logins - logging in, entering a wrong password - since that's the everyday activity a real employee's machine generates.  

- Downloaded Ubuntu server. This is the OS for SPLUNK01 (the machine thatll run SPLUNK, my SIEM). Ubuntu is used here because Splunk runs great on Linux, Linux servers are lighter on resources than Windows ones, and using a different OS for the SIEM mirrors how a real company keeps it security tooling on separate, dedicated infrastructure rather than crammed into the same box its monitoring. This VM is the "security camera room". DC01 and CLIENT01 will both forward their Windows event logs here (via the Splunk Universal Forwarder), and this is where I'll search through that data, spot the password spray pattern, and build my detection rule. Without this machine, I'll have logs sitting on the domain controller with nobody watching them. 

- Here I will document the network name. The reason I need to have a network name is because every VM I build will need to reference this exact name to join the same private network. The network name I'll go for is "detectionlab"

- Here I will log the IP scheme. This is so when I'm deep in Windows Server's network settings, I can just look back here and type it in. 
- IP Plan: 
   - DC01: 192.168.56.10
   - CLIENT01: 192.168.56.20
   - SPLUNK01: 192.168.56.30

- Here I will note which VM's get temporary internet access. 
   - DC01: stays internal network only from the start (installing from local ISO, no internet needed)
   - CLIENT01: may get temporary NAT adapter if an attack tool needs downloading
   - SPLUNK01: gets temporary second NAT adapter (needs internet for Splunk install + apt updates)
- All temporary NAT adapters get disabled before attack simulation


- Phase 2: 

- Created DC01 VM:
   - 4096 MB RAM, 2 CPUs, 60GB dynamically allocated VDI disk, attached Windows Server evaluation ISO.
   - Chose 4GB RAM because its a comfortable minimum for a Domain Controller running Active Directory. 
   - Used a dynamically allocated disk so it only takes up real storage as data is actually added, rather than reserving 60GB upfront. 
   ![DC01 VM Settings](screenshots/01-DC01-VM-Settings.png)

   - Set DC01's network adapter to Internal Network, named "detectionlab". This is the moment the isolated lab network actually gets created in VirtualBox. It doesnt exist until a VM references it by name. DC01 has no NAT/internet adapter at all, since it installs entirely from the local ISO and never needs to reach the internet.
   ![DC01 Network Config](screenshots/02-DC01-Network-Config.png)

   - Issue: faced a small issue when attempting to choose Internal Network. VirtualBox's Network settings dropdown only showed 2 of the available adapter types (NAT, Bridged Adapter). This was potentially a display/rendering bug in the VirtualBox GUI rather than a config mistake. 
   - Fix: used VirtualBox's command line to set the adapter directly. Typed "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "DC01" --nic1 intnet --intnet1 detectionlab`, then reopened DC01's settings and confirmed Internal Network (detectionlab) showed correctly. 


   # Day 2

   - Booted DC01 and began the Windows Server Installation. I chose the Desktop Experience because its more useful while learning. Real production servers often use Core instead, to save resources and reduce attack surface.

   - Issue: partway through, got a prompt saying setup detected an upgrade and booted from install media, asking whether to continue the upgrade or do a clean install. This happened because Windows automatically reboots partway through installation to continue setup, and the VM booted from the install ISO again instead of the partially installed hard disk, landing back on the installer screen. Selected "No" (clean install).

   - Continued into disk selection screen again, but this time it showed 3 partitions (EFI, Recovery, and a 59GB main partition already showing used space) rather than one block of unallocated space. This confirms the installation had already progressed once before

   - Fix: shut down DC01, restarted it, and this time did not press a key at the "boot from CD/DVD" prompt, letting it boot from the hard disk instead of the install disc. This correctly resumed installation setup. 

   - Set the built-in Administrator password. Logged into DC01 for first time. Landed in Server Manager, the default tool that opens on Windows Server login, used for managing roles and features. Installed VirtualBox Guest Additions inside DC01. This enables proper mouse integration, automatic display resizing, and shared clipboard. This was done just to make my experience better since I'll spend many hours inside these VM's. 

   - Assigned DC01 a static IP address (192.168.56.10). Subnet mask (255.255.255.0). Default gateway left blank, because a gateway would point to a router providing access to other networks/the internet, and the isolated Internal Network deliberately has no router, so theres nothing to point to. Preferred DNS server (192.168.56.10), same as DC01 address because I will be promoting DC01 to a Domain Controller which will make it the DNS server for the whole lab. Verified with 'ipconfig' in Command Prompt - confirmed IPv4 address and Subnet Mask.
   ![alt text](<screenshots/Static IP.png>)

   - Promoted DC01 to a Domain Controller, creating a new forest and domain, "lab.local". This is the step that activates AD DS. Without this, theres no domain for CLIENT01 to join and no central authority managing accounts. 


   - Installed AD DS role via Server Manager > Add Roles and Features, then ran the promotion wizard. Chose "add a new forest" (since nothing exists yet in this environment), and named the domain 'lab.local'. Set a DSRM (Directory Services Restore Mode) password. This promotion is also what makes DC01 the domain's DNS server - confirms why the static IP + DNS pointing at itself setup had to happen first, in that order. 

   - Issue: right after installing the AD DS role, clicking "promote to domain controller" gave an error saying role change status couldnt be determined, suggesting a restart was needed. 

   - Fix: restarted DC01, which let the role installation fully settle. Promotion then worked normally. 

   - DC01's sidebar in Server Manager now shows AD DS, DNS, and File and Storage Services. Opened Active Directory Users and Computers and confirmed 'lab.local' appears as an active domain with default containers. 
   ![alt text](<screenshots/Domain Controller Promotion Worked.png>)
   ![alt text](<screenshots/Domain Exists.png>)

   # Day 3

   - Created 7 test user accounts in ADUC inside the default Users container within lab.local. These accounts exist so the later password spray attack has a realistic population to target. Password spraying works by trying a few common password across many accounts, so multiple accounts are needed to meaningfully distinguish normal activity from an attack later. 
   ![alt text](<screenshots/Added Users.png>)

   - Took DC01's VM snapshot, named "Domain Controller Working". It captures AD DS running, DNS configured, static IP set, and all 7 test accounts created. This is a rollback checkpoint, so just in case if anything breaks later, DC01 can be restored to exactly this state instead of rebuilding from scratch.

   # Day 4

   - Created CLIENT01 VM: selected Windows 11 (64-bit) ISO directly in the creation wizard (unlike DC01, where the ISO was attached separately afterward). Allocated 4096 MB RAM, 2 CPUs, 60GB dynamically-allocated disk. Ticked "Use EFI", which is required for Windows 11, unlike DC01/Windows Server which could use legacy BIOS-style boot. 

   - Left "Proceed with Unattended Installation" unticked deliberately, so the Windows 11 install could be done manually, since I needed control over this to handle Microsoft account bypass later, which an automated unattended install could have skipped past incorrectly. 

   - Issue: same VirtualBox Network dropdown rendering bug as DC01, Internal Network option not selectable. 

   Fix: same VBoxManage command-line workaround, targeting CLIENT01 this time: &"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "CLIENT01" --nic1 intnet --intnet1 detectionlab

   - Added a second network adapter (NAT) for temporary internet access, per the network plan. Needed in case attack tools require downloading onto CLIENT01 later on. 

   - Issue: CLIENT01 showed a persistent black screen on boot with no error message after starting the Windows 11 install. Ruled out several causes one at a time: ISO not attached (confirmed attached), boot order (irrelevant with EFI enabled), Secure Boot (tried disabling, no change), host-side Hyper-V/Core Isolation conflicts (checked, not the cause), VirtualBox being outdated (was latest version).

   - Fix: changed Graphics Controller from VBoxSVGA to VMSVGA. This resolved the black screen, a known incompatibility between VBoxSVGA and this specific EFI + very recent Windows 11 build combination. 

   - Issue: Windows 11 setup forced a "Sign in with Microsoft" screen with no visible way to create a local account instead, even after fully disconnecting CLIENT01's network, the network screen only offered to "Install driver" (a dead end since no real adapter/driver exists) rather than showing the expected "I dont have internet" link. 

   - Fix: Pressing Fn+Shift+F10 opened the hidden command prompt, I ran oobe\bypassnro, which restarted the setup flow and made the "I dont have internet" option available, leading to a local account creation instead of a Microsoft account. 

   - Re-enabled both network adapters in CLIENT01's settings, as they were disabled to force the offline setup path during the bypass. 

   - Result: CLIENT01 now running Windows 11 Home with a local account.  

   - Assigned CLIENT01's static IP: 192.168.56.20, subnet mask 255.255.255.0, default gateway blank. Unlike DC01, set Preferred DNS server to 192.168.56.10 (DC01's address), not CLIENT01's own. CLIENT01 doesn't run any DNS service itself, so it needs to ask DC01 whenever it needs to resolve a name like lab.local.
   ![alt text](<screenshots/Assign CLIENT01's static IP.png>)

   


 
