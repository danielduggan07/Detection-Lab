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
   - Used a dynamically allocated disk so it only takes up real storage as data is actually added, rather than reserving 60GB upfront
   - Set DC01's network adapter to Internal Network, named "detectionlab". This is the moment the isolated lab network actually gets created in VirtualBox. It doesnt exist until a VM references it by name. DC01 has no NAT/internet adapter at all, since it installs entirely from the local ISO and never needs to reach the internet.
   - Issue: faced a small issue when attempting to choose Internal Network. VirtualBox's Network settings dropdown only showed 2 of the available adapter types (NAT, Bridged Adapter). This was potentially a display/rendering bug in the VirtualBox GUI rather than a config mistake. 
   - Fix: used VirtualBox's command line to set the adapter directly. Typed "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "DC01" --nic1 intnet --intnet1 detectionlab`, then reopened DC01's settings and confirmed Internal Network (detectionlab) showed correctly. 