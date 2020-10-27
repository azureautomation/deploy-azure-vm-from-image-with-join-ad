#Set Parameters

#VM Configuration
$VNName = "<VM Computer Name>"
$ResoureGroup = "<ResourceGroup Name>"
$SizeVM = "<Size of the VM>"
$Location = "<Azure Region Location>"
$VNetName = "<VNET Name>"
$SubnetName = "<Subnet Name>"
$ImageName = "<Image Name to Deploy>"
$ResoureGroupImage = "<ResourceGroup of the image>"

#Join to Domain (Need Domain Admin Credential)
$DomainName = "<Domain Name>"
$DomainJoinAdminName = "<Admin Account - Domain\UserName>"
$DomainJoinPassword = "<Admin Password>"
$OUDN = "<OU Distinguished Name>"


####MAIN Script###
	
#Get Image ID
$image = Get-AzureRMImage -ImageName:$ImageName -ResourceGroupName:$ResoureGroupImage -ErrorAction:Stop;

if ($Image) {
    #Get VNET
    $vnetDef = Get-AzureRmVirtualNetwork -ResourceGroupName:$ResoureGroup -Name:$VNetName -ErrorAction:Stop;
    #Get Subnet
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name:$SubnetName -VirtualNetwork:$vnetDef -ErrorAction:Stop;
    $nicName = "$VNName-NIC1"
    #Create NIC
    $nic = New-AzureRmNetworkInterface -ResourceGroupName:$ResoureGroup -Location:$Location -Name:$nicName -SubnetId:$subnet.Id -ErrorAction:Stop;
   
    #Provide Local Admin Credential
    $Cred = Get-Credential -Message:"Please Provide Local Admin User for VM" -ErrorAction:Stop;
    if (!$Cred) {
        Write-Host "Error: Invaild Local Admin Credential (The Windows will be close after 3 seconds)";
        sleep -Seconds:3;
        Exit -1
    }

    #VM Configuration
    $vm = New-AzureRmVMConfig -VMName $VNName -VMSize $SizeVM;
    $vm = Set-AzureRmVMSourceImage -VM $vm -Id $image.Id;
    $vm = Set-AzureRmVMOSDisk -VM $vm  -StorageAccountType standardLRS -DiskSizeInGB 128 -CreateOption FromImage -Caching ReadWrite;
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VNName -Credential $Cred -ProvisionVMAgent -EnableAutoUpdate;
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id;

    #Create Azure VM
    try {
        New-AzureRmVM -VM $vm -ResourceGroupName $ResoureGroup -Location $Location;
    } catch {
        $ErrorMessage = $_.Exception.Message;
        Write-Host "Failed To Create VM with error $errorMessage (The Windows will be close after 3 seconds)";
        sleep -Seconds:3;
        Exit -1
    }
    
    #Join to AD with ADExtension
    try {
        Set-AzureRMVMExtension -VMName $VNName -ResourceGroupName $ResoureGroup -Name "JoinAD" -ExtensionType "JsonADDomainExtension" -Publisher "Microsoft.Compute" -TypeHandlerVersion "1.0" -Location $Location -Settings @{ "Name" = $DomainName; "OUPath" = "$OUDN"; "User" = $DomainJoinAdminName; "Restart" = "true"; "Options" = 3} -ProtectedSettings @{ "Password" = $DomainJoinPassword}
    } catch {
        $ErrorMessage = $_.Exception.Message;
        Write-Host "Failed To Join Domain with error $errorMessage";
    }
}