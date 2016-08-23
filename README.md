New-Lease-Notifier-DHCP
creates a log of MAC addresses from DHCP server. When run multiple times, this script will detect any new DHCP leases by comparing with the previously created log, notify sysadmin via email, and update its log with relevant values from the lease. Best used with Windows Task Scheduler.

Be sure to have Windows Remote Server Administration Tools and to modify the information located within the first two regions of the script to suit your needs.

Verified working on PowerShell version 5+ on Windows Server 2008 r2, Windows 7 Professional sp1 and sp2, and Windows 10. 
