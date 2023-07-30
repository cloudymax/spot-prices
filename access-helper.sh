#!/bin/bash

# Action to perform (add or remove)
export action=$1

# Public IP Address to add to firewalls
export runner_ip=$2

# Resource group name
export resource_group=$3

rg_exists(){
    echo "🔍 Checking if resource group exists..."
    exists=$(az group list \
        --query "[*].name" \
        -o tsv |\
        grep -cw "$resource_group")

    if [ "$exists" -gt "0" ]; then
        echo " > Resource Group exists."
    else
        echo " ⚠️ Resource group not found"
        exit
    fi
}


find_names()
{
    # Name of the storage account
    export storage_account=$(az storage account list \
        --resource-group $resource_group \
        --query [*].name -o tsv)

    # Name of the Key Vault
    export key_vault=$(az keyvault list \
        --resource-group $resource_group \
        --query [*].name -o tsv)


    # Name of the Container Registry
    export container_registry=$(az acr list \
        --resource-group $resource_group \
        --query [*].name -o tsv)
}

# Check if the IP is present in the Storage Account firewall exception list
storage_account()
{
    echo "🔍 Checking if IP address exists in"\
        "Storage Account exception list..."

    ip_check=$(az storage account network-rule list \
        --account-name "$storage_account" \
        --query "ipRules[*].ipAddressOrRange" \
        --output tsv|\
        grep -c "$runner_ip")

    if [ "$ip_check" -gt "0" ]; then
        echo " > IP present in exception list"
    else
        echo " > IP not present in exception list"
    fi

    if [ "$ip_check" -gt "0" ] && [ "$action" == "remove" ]; then
        echo " > Removing now..."
        az storage account network-rule $action \
            --resource-group "$resource_group" \
            --account-name "$storage_account" \
            --ip-address "$runner_ip" >> access-helper.log
    fi

    if [ "$ip_check" -lt "1" ] && [ "$action" == "add" ]; then
        echo " > Adding now..."
        az storage account network-rule $action \
            --resource-group "$resource_group" \
            --account-name "$storage_account" \
            --ip-address "$runner_ip" >> firewall.log
    fi
}

# Check if the IP is present in the Key Vault firewall exception list
keyvault()
{
    echo "🔍 Checking if IP address exists in"\
        "Key Vault exception list..."

    ip_check=$(az keyvault network-rule list \
        --name "$key_vault" \
        --query "ipRules[*].value" \
        --output tsv |\
        grep -c "$runner_ip")

    if [ "$ip_check" -gt "0" ]; then
        echo " > IP present in exception list"
    else
        echo " > IP not present in exception list"
    fi

     if [ "$ip_check" -gt "0" ] && [ "$action" == "remove" ]; then
        echo " > Removing now..."
        az keyvault network-rule $action \
            --name "$key_vault" \
            --resource-group "$resource_group" \
            --ip-address "$runner_ip" >> firewall.log
     fi

     if [ "$ip_check" -lt "1" ] && [ "$action" == "add" ]; then
        echo " > Adding now..."
        az keyvault network-rule $action \
            --name "$key_vault" \
            --resource-group "$resource_group" \
            --ip-address "$runner_ip" >> firewall.log
     fi
}

# Check if the IP is present in the Container Registry firewall exception list
registry()
{
    echo "🔍 Checking if IP address exists in"\
        "Container Registry exception list..."

    acr_tier=$(az acr list \
        --resource-group "$resource_group" \
        --query [*].sku.tier \
        -o tsv)

    if [ "$acr_tier" == "Basic" ]; then
        echo "⚠️ ACR 'Basic' tier does not support IP"\
            "firewall resrictions. Skipping..."
        exit
    fi

    ip_check=$(az acr network-rule list \
        --name "$container_registry" \
        --query "ipRules[*].value" \
        --output tsv |\
        grep -c "$runner_ip")

    if [ "$ip_check" -gt "0" ]; then
        echo " > IP already present in exception list"
    else
        echo " > IP not present in exception list. Adding now..."
    fi

    if [ "$ip_check" -gt "0" ] && [ "$action" == "remove" ]; then
        echo " > Removing now..."
        az acr network-rule $action \
            --name "$container_registry" \
            --resource-group "$resource_group" \
            --ip-address "$runner_ip" >> firewall.log
    fi

    if [ "$ip_check" -lt "1" ] && [ "$action" == "add" ]; then
        echo " > Adding now..."
        az acr network-rule $action \
            --name "$container_registry" \
            --resource-group "$resource_group" \
            --ip-address "$runner_ip" >> firewall.log
    fi
}

rg_exists
find_names
storage_account
keyvault
registry
