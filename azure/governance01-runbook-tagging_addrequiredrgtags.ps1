<#
    .DESCRIPTION
      This script add every *required* ResourceGroup tags into each resource contained in it.
      It does not ovverride existing tags.

#>

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

$requiredTags = @("bl", "env", "owner", "region", "svc")

$resGroups = Get-AzureRmResourceGroup
foreach ($resGroup in $resGroups) {
    if ($resGroup.Tags -ne $null) {
		$resources = $resGroup | Find-AzureRmResource
		foreach ($resource in $resources)
		{
            Write-Output $resource.Name

            $resourcetagsource = (Get-AzureRmResource -ResourceId $resource.ResourceId).Tags
            if ($resourcetagsource -eq $null) {
                $resourcetagsource =  @{}
            }
            $resourcetags = $resourcetagsource
            foreach ($tag in $resGroup.Tags.GetEnumerator())
            {
                if ($requiredTags.contains($tag.Name) -And !$resourcetagsource.ContainsKey($tag.Name)) { $resourcetags.Add($tag.Name,$tag.Value) }
            }

			Set-AzureRmResource -Tag $resourcetags -ResourceId $resource.ResourceId -Force
		}
	}
}
