terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.64.0"
    }
  }
}
# Define Azure provider
provider "azurerm" {

   features {}
}
# Create resource group
resource "azurerm_resource_group" "example" {
  name     = "rgname"
  location = "eastus"  # Update with your desired location
}

resource "azurerm_network_security_group" "securityweb" {
  name                = "nsg_webtiernsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

	# Create Azure Virtual Network
	resource "azurerm_virtual_network" "vnet" {
	  name                = "virtualNetworks_myVNet"
	  address_space       = ["10.0.0.0/16"]
	  location            = azurerm_resource_group.example.location  # Update with your desired region
	  resource_group_name = azurerm_resource_group.example.name
	  depends_on = [ 
	       azurerm_network_security_group.securityweb,
           azurerm_network_security_group.securityapp
	]
    }

resource "azurerm_subnet" "subnet1" {
	  name                 = "web-tier-subnet"
	  resource_group_name  = azurerm_resource_group.example.name
	  virtual_network_name = azurerm_virtual_network.vnet.name
	  address_prefixes     = ["10.0.2.0/24"]
	}

resource "azurerm_network_interface" "nic" {
  count = 2  
  name                = "Interface_web_tier-${count.index}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  
  ip_configuration {    
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
     azurerm_subnet.subnet1
  ]
}

resource "azurerm_availability_set" "avail1" {
  name                = "availabilitySets_web_tier"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  platform_fault_domain_count = 3
  platform_update_domain_count = 3
}

resource "azurerm_windows_virtual_machine" "vm" {
  count               = 2 # Count Value read from variable
  name                = "web-vm-${count.index}" # Name constructed using count and pfx
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_DS1_v2"
  admin_username      = "azureuser"
  admin_password      = "Welcome_123"
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [ 
     azurerm_availability_set.avail1,
     azurerm_network_interface.nic
   ]
}

resource "azurerm_public_ip" "lb_public_ip" {
  name                = "my-lb-public-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

resource "azurerm_lb" "lb" {
  name                = "my-lb"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  frontend_ip_configuration {
    name                 = "my-lb-frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }
}
  resource "azurerm_lb_backend_address_pool" "backendpool"{
    name = "my-lb-backend-pool"
    loadbalancer_id = azurerm_lb.lb.id
  }
  resource "azurerm_lb_probe" "probe1"{
    name            = "my-lb-probe"
    protocol        = "Tcp"
    port            = 80
    loadbalancer_id = azurerm_lb.lb.id
  }
  resource "azurerm_lb_rule" "publicrule" {
    name                   = "my-lb-rule"
    protocol               = "Tcp"
    frontend_port          = 80
    backend_port           = 80
    frontend_ip_configuration_name = "my-lb-frontend-ip"
    backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.backendpool.id}"]
    probe_id               = azurerm_lb_probe.probe1.id
    loadbalancer_id = azurerm_lb.lb.id
  }
#associate network Interface and Standard load balancer
resource "azurerm_network_interface_backend_address_pool_association" "business-tier-pool" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic.*.id[count.index]
  ip_configuration_name   = azurerm_network_interface.nic.*.ip_configuration.0.name[count.index]
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id

}

##Application Layer

resource "azurerm_network_security_group" "securityapp" {
  name                = "nsg_apptiernsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}


resource "azurerm_subnet" "subnet2" {
	  name                 = "app-tier-subnet"
	  resource_group_name  = azurerm_resource_group.example.name
	  virtual_network_name = azurerm_virtual_network.vnet.name
	  address_prefixes     = ["10.0.7.0/24"]
	}

resource "azurerm_network_interface" "nicapp" {
  count = 2  
  name                = "Interface_web_tier-${count.index}-nicapp"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  
  ip_configuration {    
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
     azurerm_subnet.subnet2
  ]
}

resource "azurerm_availability_set" "availapp" {
  name                = "availabilitySets_app_tier"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  platform_fault_domain_count = 3
  platform_update_domain_count = 3
}

resource "azurerm_windows_virtual_machine" "vmapp" {
  count               = 2 # Count Value read from variable
  name                = "app-vm-${count.index}" # Name constructed using count and pfx
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_DS1_v2"
  admin_username      = "azureuser"
  admin_password      = "Welcome_123"
  network_interface_ids = [
    azurerm_network_interface.nicapp[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [ 
     azurerm_availability_set.avail1,
     azurerm_network_interface.nic
   ]
}


resource "azurerm_lb" "lb1" {
  name                = "my-lb-internal"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  frontend_ip_configuration {
    name                 = "my-lb-frontend-ip-internal"	
    subnet_id            =azurerm_subnet.subnet2.id
    private_ip_address = "Dynamic"
  }
}
  resource "azurerm_lb_backend_address_pool" "backendpool1"{
    name = "my-lb-backend-pool-internal"
    loadbalancer_id = azurerm_lb.lb1.id
  }
  resource "azurerm_lb_probe" "probe2"{
    name            = "my-lb-probe-internal"
    protocol        = "Tcp"
    port            = 80
    loadbalancer_id = azurerm_lb.lb1.id
  }
  resource "azurerm_lb_rule" "privaterule" {
    name                   = "my-lb-rule-app"
    protocol               = "Tcp"
    frontend_port          = 80
    backend_port           = 80
    frontend_ip_configuration_name = "my-lb-frontend-ip-internal"
    backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.backendpool1.id}"]
    probe_id               = azurerm_lb_probe.probe2.id
    loadbalancer_id = azurerm_lb.lb1.id
  }
#associate network Interface and Standard load balancer
resource "azurerm_network_interface_backend_address_pool_association" "business-tier-pool1" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic.*.id[count.index]
  ip_configuration_name   = azurerm_network_interface.nic.*.ip_configuration.0.name[count.index]
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool1.id

}

#database layer 

# Create Azure SQL Database for the data layer
resource "azurerm_sql_server" "database_server" {
  name                         = "database-server"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = azurerm_resource_group.example.location
  version                      = "12.0"
  administrator_login          = "adminuser"
  administrator_login_password = "password123"
}

resource "azurerm_sql_database" "database" {
  name                         = "example-db"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = azurerm_resource_group.example.location
  server_name                  = azurerm_sql_server.database_server.name
  edition                      = "Basic"
  requested_service_objective_name = "Basic"
  collation                    = "SQL_Latin1_General_CP1_CI_AS"
}


# Create Azure Virtual Network Rule to allow access from app tier
resource "azurerm_sql_virtual_network_rule" "app_network_rule" {
  name                = "app-network-rule"
  server_name         = azurerm_sql_server.database_server.name
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.subnet2.id
}














