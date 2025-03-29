# ========== Variabler ==========
RESOURCE_GROUP="demo-rg"
LOCATION="northeurope"
VNET_NAME="demo-vnet"
SUBNET_NAME="shared-subnet"
NSG_NAME="demo-nsg"
BASTION_ASG="asg-bastion"
REVERSE_ASG="asg-reverse"
BASTION_NIC="nic-bastion"
REVERSE_NIC="nic-reverse"
APP_NIC="nic-app"
ADMIN_USERNAME="azureuser"
VM_IMAGE="Ubuntu2204"
VM_SIZE="Standard_B1s"

# ========== 1. Resource Group ==========
az group create --name $RESOURCE_GROUP --location $LOCATION

# ========== 2. ASGs ==========
az network asg create --resource-group $RESOURCE_GROUP --name $BASTION_ASG --location $LOCATION
az network asg create --resource-group $RESOURCE_GROUP --name $REVERSE_ASG --location $LOCATION

# ========== 3. NSG ==========
az network nsg create --resource-group $RESOURCE_GROUP --name $NSG_NAME --location $LOCATION

# ========== 4. VNet + Subnet (gemensam) ==========
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $SUBNET_NAME \
  --subnet-prefix 10.0.0.0/24 \
  --network-security-group $NSG_NAME

# ========== 5. NSG-regler ==========

# SSH från Internet till Bastion
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME \
  --name AllowSSHToBastion --priority 100 --access Allow --direction Inbound --protocol Tcp \
  --source-address-prefixes Internet --destination-asgs $BASTION_ASG --destination-port-ranges 22

# SSH från Bastion till Reverse
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME \
  --name AllowSSHToReverse --priority 110 --access Allow --direction Inbound --protocol Tcp \
  --source-asgs $BASTION_ASG --destination-asgs $REVERSE_ASG --destination-port-ranges 22

# SSH från Bastion till App
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME \
  --name AllowSSHToApp --priority 120 --access Allow --direction Inbound --protocol Tcp \
  --source-asgs $BASTION_ASG --destination-port-ranges 22

# HTTP från Internet till Reverse
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME \
  --name AllowHTTPToReverse --priority 130 --access Allow --direction Inbound --protocol Tcp \
  --source-address-prefixes Internet --destination-asgs $REVERSE_ASG --destination-port-ranges 80

# HTTP från Reverse till App
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME \
  --name AllowHTTPToAppFromReverse --priority 140 --access Allow --direction Inbound --protocol Tcp \
  --source-asgs $REVERSE_ASG --destination-port-ranges 80

# ========== 6. Publika IPs ==========
az network public-ip create --resource-group $RESOURCE_GROUP --name BastionIP --allocation-method Static
az network public-ip create --resource-group $RESOURCE_GROUP --name ReverseIP --allocation-method Static

# ========== 7. NICs ==========
az network nic create --resource-group $RESOURCE_GROUP --name $BASTION_NIC \
  --vnet-name $VNET_NAME --subnet $SUBNET_NAME --public-ip-address BastionIP \
  --application-security-groups $BASTION_ASG

az network nic create --resource-group $RESOURCE_GROUP --name $REVERSE_NIC \
  --vnet-name $VNET_NAME --subnet $SUBNET_NAME --public-ip-address ReverseIP \
  --application-security-groups $REVERSE_ASG

az network nic create --resource-group $RESOURCE_GROUP --name $APP_NIC \
  --vnet-name $VNET_NAME --subnet $SUBNET_NAME

# ========== 8. VMs med generate-ssh-keys ==========
az vm create --resource-group $RESOURCE_GROUP --name vm-bastion --nics $BASTION_NIC \
  --image $VM_IMAGE --size $VM_SIZE --admin-username $ADMIN_USERNAME \
  --generate-ssh-keys --location $LOCATION

az vm create --resource-group $RESOURCE_GROUP --name vm-reverse --nics $REVERSE_NIC \
  --image $VM_IMAGE --size $VM_SIZE --admin-username $ADMIN_USERNAME \
  --generate-ssh-keys --location $LOCATION

az vm create --resource-group $RESOURCE_GROUP --name vm-app --nics $APP_NIC \
  --image $VM_IMAGE --size $VM_SIZE --admin-username $ADMIN_USERNAME \
  --generate-ssh-keys --location $LOCATION
