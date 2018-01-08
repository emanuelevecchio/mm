$connectionName = "AzureRunAsConnection"
try
{
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$resGroups = Get-AzureRmResourceGroup
foreach ($rg in $resGroups) {
    $rgName = $rg.ResourceGroupName.Trim()
    Write-Output "DEBUG: looping on RG $rgName"

    $vault = Get-AzureRmRecoveryServicesVault –ResourceGroupName $rgName
    if (($vault | Measure).Count -ne 1) {
        Write-Output "DEBUG: no (or more than 1) Vault found in RG $rgName, skipping ..."
        continue
    }
    Set-AzureRmRecoveryServicesVaultContext -vault $vault

    $pol=Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name "DefaultPolicy"
    if (($pol | Measure).Count -gt 1) {
        Write-Output "DEBUG: more than 1 DefaultPolicy found in RG $rgName, skipping ..."
        continue
    }

    $containers=Get-AzureRmRecoveryServicesBackupContainer -ContainerType "AzureVM" -Status Registered
    $vms=Get-AzureRmVM -ResourceGroupName $rgName

    $FriendlyName=$containers.FriendlyName
    if ($FriendlyName.count -eq 0){
        foreach ($vm in $vms){
            #Write-Output $vm.Tags
            #exit

            $vmName = $vm.Name.Trim()
	        if($vm.Tags.ContainsKey("backup") -AND $vm.Tags.Get_Item("backup") -match "yes"){
                Write-Output "DEBUG: found 'backup' tag set to 'yes', enabling backup on VM $vmName ..."
		        Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name $vm.Name -ResourceGroupName $rgName
	        } else {
                Write-Output "DEBUG: backup tag not found or not set to 'yes' on VM $vmName"
            }
        }
    }					
    else{
        foreach ($vm in $vms){
            $vmName = $vm.Name.Trim()
            $found=$false
            $tobebackup=$false

            # look for already-backup-configured VMs
            foreach ($name in $FriendlyName){
                if ($vm.Name -Match $name -AND $found -ne $true){
	        	    $found=$true
			    }
	        }		
	        if ($vm.Tags.ContainsKey("backup") -AND $vm.Tags.Get_Item("backup") -match "yes") {
                Write-Output "DEBUG: (FRIENDLYNAME=Y) found 'backup' tag set to 'yes' for VM $vmName"
                $tobebackup=$true
	        } else {
                Write-Output "DEBUG: (FRIENDLYNAME=Y) backup tag not found or not set to 'yes' on VM $vmName"
            }
    
            # schedule backup only if not already backupped AND proper tag (backup=yes) is set
            if ($found -eq $false -and $tobebackup -eq $true) {
                Write-Output "DEBUG: (FRIENDLYNAME=Y) VM not already backupped, enabling backup on VM $vmName ..."
                Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name $vm.Name -ResourceGroupName $rgName
	        } else {
                Write-Output "DEBUG: (FRIENDLYNAME=Y) backup already configured or not needed for VM $vmName"
            }
    
        }
    
    }
}
