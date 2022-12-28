#!/bin/bash

# This script will grab the price and machine size details of spot instances
# from multiple cloud providers.
# Currently Supported providers are:
# - AWS ec2 Spot
# - Azure VM Spot
# - Equinix Metal Spot (WiP)
# - Google Compute Engine Spot (Wip)

pip3.10 install rich
pip3.10 install csvkit

echo "Vendor,Name,vCores,Memory,Boot,Storage,Price" > table.csv

AWS(){
    INSTANCE_TYPE_LIST=("m6i.large" "m6i.2xlarge" "m6i.4xlarge" "m6a.large" "m6a.2xlarge" "m6a.4xlarge")
    ZONE="eu-central-1a"
    START=$(date +%Y-%m-%dT%H:%M:%S)
    END=$(date +%Y-%m-%dT%H:%M:%S)

    for INSTANCE in "${INSTANCE_TYPE_LIST[@]}"
    do
      INSTANCE_TYPE="$INSTANCE"

      echo "Checking $INSTANCE"

      VCORES=$(aws ec2 describe-instance-types \
      --instance-types $INSTANCE_TYPE --output text |grep "VCPUINFO" |awk '{print $4}')

      # The aws cli returns details in Mebibytes which have to be converted
      # to Bytes then to GigaBytes for a correct readout
      MEMORY_MB=$(aws ec2 describe-instance-types \
      --instance-types $INSTANCE_TYPE --output text |grep "MEMORYINFO" |awk '{print $2}')
      MEMORY_B=$(echo "$MEMORY_MB" | numfmt --from-unit=Mi)
      MEMORY_GB=$(numfmt --to iec --format "%8.4f" $MEMORY_B)

      DISK=$(aws ec2 describe-instance-types \
      --instance-types $INSTANCE_TYPE --output text |grep "SUPPORTEDROOTDEVICETYPES" |awk '{print $2}')

      if [ "$DISK" == "ebs" ]; then
          DISK=""
      fi

      # We only want the most recent entry so the date range is juts the current day
      PRICE=$(aws ec2 describe-spot-price-history \
      --availability-zone $ZONE \
      --instance-types $INSTANCE_TYPE \
      --product-description "Linux/UNIX" \
      --start-time $START \
      --end-time $END --output text |awk '{print $5}')

      ROUNDED_PRICE=$(printf "%.2f \n" $PRICE)
      echo "AWS,$INSTANCE_TYPE,$VCORES,${MEMORY_GB%.*},30,$DISK,$ROUNDED_PRICE" >> table.csv
    done
}

Azure(){
    INSTANCE_TYPE_LIST=("Standard_D4d_v4" "Standard_D8d_v4" "Standard_D16d_v4")

    # cached strings to shorten the rest call
    export API_URL="https://prices.azure.com/api/retail/prices"
    export ARN_URL_BASE="https://management.azure.com/subscriptions"
    export LOCATION="'EU West'"
    export REGION="westeurope"
    export SERVICE_NAME="'Virtual Machines'"
    export SERVICE_FAMILY="'Compute'"
    export API_VERSION="api-version=2022-08-01"
    export SUBSCRIPTION_ID=""
    export ARN_URL_FILLER=$(echo "providers/Microsoft.Compute/locations")

    for INSTANCE in "${INSTANCE_TYPE_LIST[@]}"
    do
      ARM_SKU=$INSTANCE
      METER_NAME=$(echo "$ARM_SKU Spot"| sed 's/Standard_//g' |sed 's/_/ /g')
      ARM_SKU_NAME=$(echo "$ARM_SKU")

      echo "Checking $INSTANCE"

      MACHINE_SIZE=$(az rest --method get \
        --uri "$ARN_URL_BASE/$SUBSCRIPTION_ID/$ARN_URL_FILLER/$REGION/vmSizes?$API_VERSION" \
        --query "[value][0][?contains(name, '$INSTANCE')]" -o tsv)

      CORES=$(echo $MACHINE_SIZE |awk '{print $4}')

      # Converting memory and disk sizes from Mebibytes to Gigabytes
      MEMORY_MB=$(echo $MACHINE_SIZE |awk '{print $2}')
      MEMORY_B=$(echo "$MEMORY_MB" | numfmt --from-unit=Mi)
      MEMORY_GB=$(numfmt --to iec --format "%8.4f" $MEMORY_B)
      STORAGE_DISK_MB=$(echo $MACHINE_SIZE |awk '{print $6}')
      STORAGE_DISK_B=$(echo "$STORAGE_DISK_MB" | numfmt --from-unit=Mi)
      STORAGE_DISK_GB=$(numfmt --to iec --format "%8.4f" $STORAGE_DISK_B)
      BOOT_DISK_MB=$(echo $MACHINE_SIZE |awk '{print $5}')
      BOOT_DISK_B=$(echo "$BOOT_DISK_MB" | numfmt --from-unit=Mi)
      BOOT_DISK_GB=$(numfmt --to iec --format "%8.4f" $BOOT_DISK_B)

      PRICE=$(echo "az rest --method get \
        --uri \"${API_URL}?\\\$filter=location eq $LOCATION \
        and serviceName eq $SERVICE_NAME \
        and serviceFamily eq $SERVICE_FAMILY \
        and armSkuName eq '$ARM_SKU_NAME' \
        and meterName eq '$METER_NAME'"\" \
        --query \"[Items][0][*].{Name:productName, SKU:armSkuName, \
        Location:location, Price:retailPrice}\" \
        --only-show-errors \
        -o tsv |bash |grep -v Windows |awk '{print $NF}')

      ROUNDED_PRICE=$(printf "%.2f \n" $PRICE)
      echo "Azure,$INSTANCE,$CORES,${MEMORY_GB%.*},${BOOT_DISK_GB%.*},${STORAGE_DISK_GB%.*},$ROUNDED_PRICE" >> table.csv
    done
}

AWS
Azure
csvsort -c 7 table.csv > sorted.csv
rich sorted.csv
#--export-svg my_cool_svg.svg
