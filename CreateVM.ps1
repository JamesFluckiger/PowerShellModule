$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($sp.ApplicationId, $sp.Secret)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId


$Info = @{
    RGName = "rg-jflukepowershellmodule-temp-westus2"
    Location = "westus2"
    VnetName = "vnet-powershellmodule-temp-westus2-01"
    NSGName = "nsg-powershellmodule-temp-westus2-01"
    Subnet1Name = "Subnet1"
    NICName = "nic-winserver01"
    VMName = "winserver01"

    
    
}



$Tags = @{
    ApplicationName     = "ACETECHWEEK"
    AppTypeRole         = "RG"
    DataProtection      = "NotProtected"
    DRTier              = "None"
    Environment         = "ATS"
    Location            = "USW2Z"
    NotificationContact = "james.fluckiger@cdw.com"
    ProductCostCenter   = "ATS"
    SupportResponseSLA  = "None"
    WorkloadType        = "WebServer"
    Owner               = "James Fluckiger"
}


#Deploy rg.
New-AzResourceGroup `
    -ResourceGroupName $Info.RGName `
    -Location $Info.Location `
    -Tags $Tags `
    -Force

$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule `
-Description "Allow RDP" `
-Access Allow `
-Protocol Tcp `
-Direction Inbound `
-Priority 100 `
-SourceAddressPrefix Internet `
-SourcePortRange * `
-DestinationAddressPrefix * `
-DestinationPortRange 3389

$rule2 = New-AzNetworkSecurityRuleConfig -Name web-rule `
-Description "Allow HTTP" `
-Access Allow `
-Protocol Tcp `
-Direction Inbound `
-Priority 101 `
-SourceAddressPrefix Internet `
-SourcePortRange * `
-DestinationAddressPrefix * `
-DestinationPortRange 80


#NSG Config.
$NSG = New-AzNetworkSecurityGroup -Name $Info.NSGName -ResourceGroupName $Info.RGName -Location $Info.Location -SecurityRules $rule1,$rule2 -Force


#Subnet Config.
$Subnet1 = New-AzVirtualNetworkSubnetConfig -Name $Info.Subnet1Name -NetworkSecurityGroup $NSG -AddressPrefix 10.10.0.0/24


#Deploy vnet.
$Vnet = New-AzVirtualNetwork `
    -ResourceGroupName $Info.RGName `
    -Location $Info.Location `
    -Name $Info.VnetName `
    -AddressPrefix 10.10.0.0/16 `
    -Subnet $Subnet1 `
    -Force
    

#Deploy NIC.

$NIC = New-AzNetworkInterface -Name $Info.NICName -ResourceGroupName $Info.RGName -Location $Info.Location -SubnetId $Vnet.Subnets[0].ID -PrivateIpAddress 10.10.0.100 -Force

#Configure VM.
$VM = New-AzVmConfig `
    -VMName $Info.VMName `
    -VMSize Standard_B2ms

$VM = Set-AzVMOperatingSystem -VM $VM -Windows -ComputerName $Info.VMName -Credential $Credentials -ProvisionVMAgent -EnableAutoUpdate
$VM = Add-AzVMNetworkInterface -VM $VM -Id $NIC.Id
$VM = Set-AzVMSourceImage -VM $VM -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-datacenter-zhcn-g2' -Version latest


#Deploy VM.
New-AzVM -ResourceGroupName $Info.RGName -Location $Info.Location -VM $VM -Tag $Tags