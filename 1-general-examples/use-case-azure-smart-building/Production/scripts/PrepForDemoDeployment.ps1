param(
	[Parameter(Mandatory=$true)][Alias("rg")][String]$resourceGroupName,
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = '.\azcreds.txt',
	[Parameter(Mandatory=$false)][Alias("tnt")][String]$tenantId = '92b796c5-5839-40a6-8dd9-c1fad320c69b',	
	[Parameter(Mandatory=$false)][Alias("l")][String]$location = 'West US 2',
	[Parameter(Mandatory=$false)][Alias("t")][String]$templateFile = 'azuredeploy.json',
	[Parameter(Mandatory=$false)][Alias("p")][String]$templateParameterFile = 'azuredeploy_parameters.json',
	[Parameter(Mandatory=$false)][Alias("of")][String]$outFile
)
function Get-Credentials 
{
	if ($credsFile -eq '') {
		$userName = Read-Host "Enter App Registration (Service Principal)"
		$securepswd = Read-Host "Enter Client Secret" -AsSecureString
		$password = ConvertFrom-SecureString -SecureString $securepswd -AsPlainText
	}
	else {
		try {
			$credsInFile = Get-Content -Path $credsFile -TotalCount 2
		}
		catch {
			"Some error occurred"
			$_.Exception.Message
			exit
		}
		$userName = $credsInFile[0]
		$password = $credsInFile[1]
	}
	
	$creds = @($userName, $password)
	return $creds
}

#
#	Get AppRegistration and Client Secret, then connect to an Azure account
#
$azCreds = Get-Credentials	
$servicePrincipal = $azCreds[0]
$password = ConvertTo-SecureString $azCreds[1] -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $password)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

if ($templateParameterFile.ToLower() -eq 'none') {
	$deploymentOutput = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFile 
}
else {
	$deploymentOutput = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
	-TemplateFile $templateFile -TemplateParameterFile $templateParameterFile 
}

if (($outFile -ne '') -And ($deploymentOutput.ProvisioningState -eq "Succeeded")) {
	$storageAccountName = $deploymentOutput.Outputs.storageAccountName.Value
	$storageAccountKey = $deploymentOutput.Outputs.storageAccountKey.Value
	$sqlServerName = $deploymentOutput.Outputs.sqlServerName.Value
	$storageAccountNameRecord = "xxxxstorageAccountNamexxxx:$storageAccountName"
	$sqlServerNameRecord = "xxxxsqlnamexxxx:$sqlServerName"
	$storageAccountKeyRecord = "xxxxstorageAccountKeyxxxx:$storageAccountKey"
	
	$storageAccountNameRecord | Add-Content $outFile
	$storageAccountKeyRecord | Add-Content $outFile
	$sqlServerNameRecord | Add-Content $outFile
}

$deploymentOutput

if ($deploymentOutput.ProvisioningState -eq "Succeeded") {
	exit(0)
} else {
	exit(1)
}