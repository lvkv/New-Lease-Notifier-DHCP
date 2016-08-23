# MAC DHCP Notify
# Lukas Velikov (modified from Assaf Miron's Get-DHCPLeases script)
#
# Creates a log of MAC addresses from DHCP server. When run multiple
# times, this script will detect any new DHCP leases by comparing with 
# a previously created log, notify sysadminvia email, and update its 
# log with relevant values from the lease. Best when automated.


#region Server and directory information

    $DHCP_SERVER = "pvadc01.pva.local"
    $LOG_FOLDER = "C:\MAC_NOTIFY_LOGS"
    $MACsLog = $LOG_FOLDER+"\macLog.csv"
    $LeaseLog = $LOG_FOLDER+"\LeaseLog.csv"

    #If directory does not exist, create it
    If(!(test-path $LOG_FOLDER)){
        New-Item $LOG_FOLDER -type directory
    }

#endregion

#region Email notification information

    $sysAdmin = "LVelikov@PVA.net"
    $subject = "New DHCP Entries"
    $body = "The following entries have been detected and added to the log:`n"
    $from = "do-not-reply@pvadc01"
    $smtp = "PVAMail2kx.PVA.local"

#endregion

#region Creating required objects

    #region Scope object and members

        $Scope = New-Object psobject
        $Scope | Add-Member noteproperty "Address" ""
        $Scope | Add-Member noteproperty "Mask" ""
        $Scope | Add-Member noteproperty "State" ""
        $Scope | Add-Member noteproperty "Name" ""
        

        $Scope.Address = @()
        $Scope.Mask = @()
        $Scope.State = @()
        $Scope.Name = @()
        

    #endregion

    #region LeaseClients object and members

        $LeaseClients = New-Object psObject
        $LeaseClients | Add-Member noteproperty "IP" ""
        $LeaseClients | Add-Member noteproperty "Name" ""
        $LeaseClients | Add-Member noteproperty "Mask" ""
        $LeaseClients | Add-Member noteproperty "MAC" ""
        $LeaseClients | Add-Member noteproperty "Expires" ""
        $LeaseClients | Add-Member noteproperty "Type" ""

        $LeaseClients.IP = @()
        $LeaseClients.Name = @()
        $LeaseClients.MAC = @()
        $LeaseClients.Mask = @()
        $LeaseClients.Expires = @()
        $LeaseClients.Type = @()

    #endregion

    #region LeaseReserved object and members

        $LeaseReserved = New-Object psObject
        $LeaseReserved | Add-Member noteproperty "IP" ""
        $LeaseReserved | Add-Member noteproperty "MAC" ""

        $LeaseReserved.IP = @()
        $LeaseReserved.MAC = @()

    #endregion

#endregion

#region Define commands

    #Connects to DHCP server
    $NetCommand = "netsh dhcp server \\$DHCP_SERVER"

    #Gets all Scope details on the server
    $ShowScopes = "$NetCommand show scope"

#endregion

#region Functions

    function Get-LeaseType( $LeaseType ){
    # Input: The Lease type in one Char
    # Output: The Lease type description (string)
    # Description: This function translates a Lease type Char to its relevant description

	    Switch($LeaseType){
		    "N" { return "None" }
		    "D" { return "DHCP" }
		    "B" { return "BOOTP" }
		    "U" { return "UNSPECIFIED" }
		    "R" { return "RESERVATION IP" } 
	    }
    }

    function Check-Empty( $Object ){
    # Input: An Object with values.
    # Output: A Trimmed String of the Object or '-' if it's Null.
    # Description: Check the object if it is null and return its value.

	    If($Object -eq $null){
		    return "-"
	    }
	    else{
		    return $Object.ToString().Trim()
	    }
    }

    function out-CSV ( $LogFile, $Append = $false){
    # Input: An Object with values, Boolean value if to append the file or not, a File path to a Log File
    # Output: Export of the object values to a CSV File
    # Description : This Function Exports all the Values and Headers of an object to a CSV File.
    #               The Object is recieved with the Input Const (Used with Pipelineing) or the $inputObject

	    Foreach ($item in $input){
		    $Properties = $item.PsObject.get_properties()
		    $Headers = ""
		    $Values = ""
		    $Properties | %{
                #Modified delimiters to use commas for readability and easier parsing
			    $Headers += $_.Name+","
			    $Values += $_.Value+","
		    }
		    If($Append -and (Test-Path $LogFile)) {
			    $Values | Out-File -Append -FilePath $LogFile -Encoding Unicode
		    }
	   	    else {
			    $Headers | Out-File -FilePath $LogFile -Encoding Unicode
			    $Values | Out-File -Append -FilePath $LogFile -Encoding Unicode
		    }
	    }
    }

    function export-custom ($Comparing){
    # Input: A boolean $Comparing that is true if and only if the script intends to make a log comparison  
    # Output: A log of MAC addresses 
    # Description: If $Comparing is $false, this function creates the base macLog.csv to which new MACs will be pushed and compared.
    #              If $Comparing is $true, this function creates a temporary macLog2.csv to be compared with existing macLog.csv

	    If($Comparing){
		    $macDestination = $LOG_FOLDER+"\macLog2.csv"
		    create-master $false
	    }
	    else{
		    $macDestination = $LOG_FOLDER+"\macLog.csv"
	    }
        # Removing duplicate entries (if they ever arise)
	    Import-Csv $LeaseLog | select MAC | sort MAC -Unique | Export-Csv -Path $macDestination –NoTypeInformation
	    Remove-Item $LeaseLog
    }

    function create-master($Last){
    # Input: Boolean $Last, which is $true if and only if macLog.csv is not present
    # Output: A temporary LeaseLog.csv file
    # Description: This function creates a temporary lease log file. If $Last is $true, then this function also creates the base 
    #              macLog.csv by calling export-custom $false

	    $tmpLeaseClients = New-Object psObject
	    $tmpLeaseClients | Add-Member noteproperty "IP" ""
	    $tmpLeaseClients | Add-Member noteproperty "Name" ""
	    $tmpLeaseClients | Add-Member noteproperty "Mask" ""
	    $tmpLeaseClients | Add-Member noteproperty "MAC" ""
	    $tmpLeaseClients | Add-Member noteproperty "Expires" ""
	    $tmpLeaseClients | Add-Member noteproperty "Type" ""

	    
	    For($l=0; $l -lt $LeaseClients.IP.Length;$l++){
		    $tmpLeaseClients.IP = $LeaseClients.IP[$l]
		    $tmpLeaseClients.Name = $LeaseClients.Name[$l]
		    $tmpLeaseClients.Mask =  $LeaseClients.Mask[$l]
		    $tmpLeaseClients.MAC = $LeaseClients.MAC[$l]
		    $tmpLeaseClients.Expires = $LeaseClients.Expires[$l]
		    $tmpLeaseClients.Type = $LeaseClients.Type[$l]
		    $tmpLeaseClients | out-csv $LeaseLog -append $true
	    }
	    If($Last){
		    If(Test-Path $LeaseLog){export-custom $false}
	    }
    }

    function string-format([string]$str){
    # Input: String $str, which is anticipated to be a MAC address converted from a CSV PSCustomObject
    # Output: A string without PSCustomObject | Out-String formatting
    # Description: Takes a formatted MAC address string and trims the fat, leaving only the address

        $str = $str.Replace('"',"")
        $str = $str.Replace("MAC","")
        $str = $str.Replace("---","")
        $str = $str.Replace("`n","")
        $str = $str.Replace(" ","")
        return $str
    }

#endregion

#region Get all scopes in the server

    #Run the command in the show scopes var
    $AllScopes = Invoke-Expression $ShowScopes

    for($i=5;$i -lt $AllScopes.Length-3;$i++){
	    $line = ([string]($AllScopes[$i])).Split("-")
        If(!((Check-Empty $line[0]) -eq ("192.168.80.0"))){
	        $Scope.Address += Check-Empty $line[0]
	        $Scope.Mask += Check-Empty $line[1]
	        $Scope.State += Check-Empty $line[2]
	        If (Check-Empty $line[3] -eq "-"){
		        $Scope.Name += Check-Empty $line[4]
	        }
	        else { 
                $Scope.Name += Check-Empty $line[3] 
            }
        }
    }

    $ScopesIP = $Scope | Where { $_.State -eq "Active" } | Select Address

    Foreach($ScopeAddress in $ScopesIP.Address){
	    $ShowLeases = "$NetCommand scope "+$ScopeAddress+" show clients 1"
	    $ShowReserved = "$NetCommand scope "+$ScopeAddress+" show reservedip"
	    $ShowScopeDuration = "$NetCommand scope "+$ScopeAddress+" show option"
	    $AllLeases = Invoke-Expression $ShowLeases 
	    $AllReserved = Invoke-Expression $ShowReserved 
	    $AllOptions = Invoke-Expression $ShowScopeDuration
	    for($i=0; $i -lt $AllOptions.count;$i++) { 
		    if($AllOptions[$i] -match "OptionId : 51"){ 
			    $tmpLease = $AllOptions[$i+4].Split("=")[1].Trim()
			    $tmpLease = [int]$tmpLease * 10000000; 
			    $TimeSpan = New-Object -TypeName TimeSpan -ArgumentList $tmpLease
			    
			    break;
		    } 
	    }
	    for($i=8;$i -lt $AllLeases.Length-4;$i++){
		    $line = [regex]::split($AllLeases[$i],"\s{2,}")
		    $LeaseClients.IP += Check-Empty $line[0]
		    $LeaseClients.Mask += Check-Empty $line[1].ToString().replace("-","").Trim()
		    $LeaseClients.MAC += $line[2].ToString().substring($line[2].ToString().indexOf("-")+1,$line[2].toString().Length-1).Trim()
		    $LeaseClients.Expires += $(Check-Empty $line[3]).replace("-","").Trim()
		    $LeaseClients.Type += Get-LeaseType $(Check-Empty $line[4]).replace("-","").Trim()
		    $LeaseClients.Name += Check-Empty $line[5]
	    }
	    for($i=7;$i -lt $AllReserved.Length-5;$i++){
		    $line = [regex]::split($AllReserved[$i],"\s{2,}")
		    $LeaseReserved.IP += Check-Empty $line[0]
		    $LeaseReserved.MAC += Check-Empty $line[2]
	    }
    }

#endregion

#region Logging, comparing, notifying and updating

    $macDestination = $MACsLog
    If(Test-Path $LeaseLog){
	    export-custom $false
    }
    elseif(Test-Path $macDestination){

        #region Creating temporary lease references and comparison MAC log

	        create-master $false
	        export-custom $true

        #endregion
	
        #region Temporary file destinations

	        $f1 = $LOG_FOLDER+"\macLog.csv" 
	        $f2 = $LOG_FOLDER+"\macLog2.csv"
	        $f3 = $LOG_FOLDER+"\macLog_2.csv"
	        $cDest = $LOG_FOLDER+"\difference.csv"

        #endregion
	
        #region Sorting, removing duplicates and cleanup

	        Import-Csv $f2 | sort MAC -Unique | Export-Csv -Path $f3 -NoTypeInformation
	        Remove-Item $f2

        #endregion
	
	    #region Comparing base to new log and saving differences

	        Compare-Object (Get-Content $f1) (Get-Content $f3) | Where-Object { $_.SideIndicator -eq '=>' } | select InputObject |Select-Object @{ expression={$_.InputObject}; label="MAC" } | Export-Csv -Path $cDest -NoTypeInformation
            Remove-Item $f3

        #endregion

        #region Updating log and sending email notification

            $newMACS = Import-Csv $cDest
            If(!($newMACS.Length -eq 0)){

                #region Temporary files, array and filters

                    create-master $false
                    $logEvery = Import-Csv $LeaseLog | sort MAC -Unique
                    $logMACs = Import-Csv $LeaseLog | sort MAC -Unique |select MAC 
                    $infoIndexes = @()

                #endregion

                #region Finding indices of detailed information within temporary file

                    Foreach($newMAC in $newMACS){
                        $counter = 0
                        Foreach($logMAC in $logMACs){
                            If((string-format $logMAC) -eq (string-format $newMAC)){
                                $infoIndexes += $counter
                            }
                            $counter += 1
                        }
                    }

                #endregion

                #region Building email body

                    Foreach($index in $infoIndexes){
                        $body += ($logEvery[$index] | Out-String)
                    }

                #endregion

                #region Updating log

                    $tempMACM = Import-Csv $f1
                    $tempLogM = $logMACs
                    $overWrite = $tempMACM + $tempLogM
                    Remove-Item $f1
                    $overwrite | sort MAC -Unique | Export-Csv $f1 -NoTypeInformation

                #endregion

                #region Email and cleanup

                    Send-MailMessage -To $sysAdmin -Subject $subject -Body $body -SmtpServer $smtp -From $from
                    Remove-Item $cDest
                    Remove-Item $LeaseLog

                #endregion

        }
            elseif(Test-Path $cDest){
                Remove-Item $cDest
            }

        #endregion
    
    }
    else{ 
	    create-master $true
    }

#endregion