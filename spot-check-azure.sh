#!/bin/bash

# example
# bash spot-check-azure.sh Standard_ND6s "'EU West'"

export ARM_SKU=$1
export LOCATION=$2
export METER_NAME=$(echo "'$ARM_SKU Spot'"| sed 's/Standard_//g' |sed 's/_/ /g')
export ARM_SKU_NAME=$(echo "'$ARM_SKU'")
export API_URL=https://prices.azure.com/api/retail/prices

get_all_sku_data(){
    DONE="false"
    PAGE=0

    get_page > ./"page${PAGE}.json"
    until [ "$DONE" == "true" ]
    do
        cat "./page${PAGE}.json"|jq -r '.NextPageLink'
       # if [ -z "$API_URL" ]; then
        export DONE="true"
       # else
       #     get_page > "./page${PAGE}.json"
       #     echo "Page${PAGE} ✅"
       #     let PAGE++
       #     export DONE="true"
       # fi
    done
}

get_page(){
    docker run --platform linux/amd64 \
    -e API_URL="$API_URL" \
    -e LOCATION="$LOCATION"  \
    -e SERVICE_NAME="'Virtual Machines'" \
    -e SERVICE_FAMILY="'Compute'" \
    -e METER_NAME="$METER_NAME" \
    -e ARM_SKU_NAME="$ARM_SKU_NAME" \
    -e ARM_SKU="$ARM_SKU" \
    -e ARM_CLIENT_ID=$(bw get item admin-robot |jq -r '.fields[] |select(.name=="clientId") |.value') \
    -e ARM_CLIENT_SECRET=$(bw get item admin-robot |jq -r '.fields[] |select(.name=="clientSecret") |.value') \
    -e ARM_TENANT_ID=$(bw get item admin-robot |jq -r '.fields[] |select(.name=="tenantId") |.value') \
    mcr.microsoft.com/azure-cli:2.9.1 sh -c 'az login --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" -o none && \
    echo "az rest --method get --uri \"${API_URL}?\\\$filter=location eq $LOCATION and serviceName eq $SERVICE_NAME and serviceFamily eq $SERVICE_FAMILY\""|sh'
}

get_price(){
    docker run --platform linux/amd64 \
    -e API_URL="https://prices.azure.com/api/retail/prices" \
    -e LOCATION="$LOCATION"  \
    -e SERVICE_NAME="'Virtual Machines'" \
    -e SERVICE_FAMILY="'Compute'" \
    -e METER_NAME="$METER_NAME" \
    -e ARM_SKU_NAME="$ARM_SKU_NAME" \
    -e ARM_SKU="$ARM_SKU" \
    -e ARM_CLIENT_ID=$(bw get item admin-robot |jq -r '.fields[] |select(.name=="clientId") |.value') \
    -e ARM_CLIENT_SECRET=$(bw get item admin-robot |jq -r '.fields[] |select(.name=="clientSecret") |.value') \
    -e ARM_TENANT_ID=$(bw get item admin-robot |jq -r '.fields[] |select(.name=="tenantId") |.value') \
    mcr.microsoft.com/azure-cli:2.9.1 sh -c 'az login --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" 2>&1 > /dev/null && \
    echo "az rest --method get --uri \"${API_URL}?\\\$filter=\
    location eq $LOCATION and \
    serviceName eq $SERVICE_NAME and \
    serviceFamily eq $SERVICE_FAMILY and \
    armSkuName eq $ARM_SKU_NAME and \
    meterName eq $METER_NAME"\" \
    --query \"[Items][0][*].{name:productName, sku:armSkuName, location:location, hourly_price:retailPrice, hourly_price:retailPrice, currency:currencyCode, type:type}\" \
    -o json --only-show-errors'
}

get_cpu_info(){
    export CPU=$(yq -r --prettyPrint -o=json '.vendors.azure.*.[] |select (.instance_name == env(ARM_SKU)) | .cpu' instances.yaml)

    yq -r --prettyPrint -o=json '.processors.*.[] | select (.cpu_name == env(CPU))' instances.yaml > cpu-info.json
}

main(){
    jq -s '.[0] * .[1]' cpu-info.json price.json
}

#get_price
get_all_sku_data
