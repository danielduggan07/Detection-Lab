# AD Detection Lab: Password Spray Attack & Detection

A home lab project simulating a real Active Directory environment, forwarding its logs to Splunk, launching a password spray attack against it, and building a data-driven detection rule to catch it. 

## Overview 

This project demonstrates the full lifecycle of a SOC analyst's core workflow: building the infrastructure to generate security telemetry, understand what normal activity looks like, simulating a real attack technique, and building a detection whose threshold is justified by directly observed data rather than a guessed or textbook figure. 

## Tech Stack 

VirtualBox · Active Directory · Powershell · Windows Server · Windows 11 Pro · Ubuntu Server · Splunk Enterprise

## Architecture

3 isolated virtual machines, networked on an internal-only VirtualBox network ('detectionlab', 192.168.56.0/24): 

VM1: DC01                     
 - Role: Domain Controller    
 - OS: Windows Server 
 - IP: 192.168.56.10

VM2: CLIENT01
 - Role: Domain joined workstation
 - OS: Windows 11 Pro
 - IP: 192.168.56.20

VM3: SPLUNK01
 - Role: SIEM
 - OS: Ubuntu Server + Splunk Enterprise 
 - IP: 192.168.56.30

DC01 and CLIENT01 each run the Splunk Universal Forwarder, sending Windows Security Event Log data to a dedicated "windows" index on SPLUNK01.


## Objectives 
 - Stand up a functioning Active Directory environment from scratch
 - Configure and verify Windows audit policy for authentication events
 - Forward logs from multiple hosts into a SIEM
 - Establish a real, observed baseline of normal authentication activity
 - Simulate a genuine password spray attack
 - Build a detection with a threshold justified by data, not assumption


## Build Summary 
 - Phase 0-1: Environment prep, isolated network planning
 - Phase 2: DC01, Active Directory, DNS, 7 test accounts
 - Phase 3: CLIENT01, domain joined workstation
 - Phase 4: SPLUNK01, Splunk Enterprise, forwarders, log pipeline
 - Phase 5: Audit policy verification (effective policy, not just local settings)
 - Phase 6: Authentication baseline: normal login/failure/lock-unlock activity
 - Phase 7: Password spray attack simulation (Powershell + .NET credential validation)
 - Phase 8: Data driven detection, built, tested, deployed as a live Splunk alert

 This whole process was documented in the "Documentation Progress.md" file, including troubleshooting issues and fixes, as well as screenshots. 


 ## The Detection

 **Threshold:** 3 or more distinct accounts failing to authenticate within a 1 minute window.

 **Why this number?:** measured directly from this lab's own data. Baseline activity never exceeded 1 distinct account failing per minute; the simulated attack produced 7. The threshold sits with genuine margin above observed normal noise and well below the actual attack signal.

 Below is my actual detection query itself, the literal Splunk search I built and tested. It looks at failed logon events from either machine, then extracts just the real target account name (fixing that dual-field issue I found), then groups the results into 1 minute time windows. For each minute, count distinct accounts and total failures, and only keep minutes where 3+ different accounts failed.

 ```spl
 index=windows EventCode=4625 (host=WIN-2U5EUPPQBPR OR host=CLIENT01)
 | eval real_account=mvindex(Account_Name, -1)
 | bucket _time span=1m
 | stats dc(real_account) as distinct_accounts, count as total_failures by _time
 | where distinct_accounts >= 3
 ```
Tested against both datasets: returns zero results during baseline activity, and correctly identifies all 3 minutes of the actual attack, with no false positives. 


## Challenges and Lessons Learned
 - Diagnosed why Domain Controller audit policy appeared "Not Configured" locally despite events genuinely being logged. Domain-level Group Policy overrides local settings, and 'auditpol' shows the true effective policy. 
 - Traced a missing set of lock/unlock events to an entirely separate, independently controlled audit subcategory ("Other Logon/Logoff Events")
 - Discovered that credential validation attempts from a client machine are logged by the Domain Controller, not the client itself. This is an architectural fact of how AD authentication works. 
 - Identified and corrected a Splunk field-extraction quirk (Windows 4625 events contain two merged "Account Name" values) that was silently inflating distinct-account counts. 




