New-Lease-Notifier-DHCP
creates a CSV log of MAC addresses from a specified DHCP server. When run multiple times, it will detect any new DHCP leases by comparing with the previously created log, notify sysadmin via email with more verbose information, and update the master log with relevant values from the lease. 

The script is capable of handling multiple new leases at once, support for limiting scopes will be come sometime. Use with Windows Task Scheduler. 

Be sure to have Windows Remote Server Administration Tools and to modify the information located within the first two regions of the script to suit your needs.

Verified working on PowerShell version 5+ on Windows Server 2008 r2, Windows 7 Professional sp1 and sp2, and Windows 10. 
