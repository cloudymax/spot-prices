# Spot Pricing Notes

These are just my notes, check out https://cloudoptimizer.io/ for a real implimentation 

## AWS

Getting AWS prices is actuall pretty straight-forward, each metadata filed is queryable in an intuitive way.

Resources:

- [Spot Prices](https://aws.amazon.com/ec2/spot/pricing/)
- [Spot Advisor](https://aws.amazon.com/ec2/spot/instance-advisor/)
- [Instance Types](https://aws.amazon.com/ec2/instance-types/)

Preferred Instances:

```bash
echo "Name,vCores,Memory,Drives,Price" > table.csv
INSTANCE_TYPE_LIST=("m6i.large" "m6i.2xlarge" "m6i.4xlarge")

for i in "${INSTANCE_TYPE_LIST[@]}"
do
  INSTANCE_TYPE="m6i.large"
  ZONE="eu-central-1a"
  INSTANCES="m6i.large"
  START=$(date +%Y-%m-%dT00:00:00)
  END=$(date +%Y-%m-%dT%H:%M:%S)

  VCORES=$(aws ec2 describe-instance-types \
  --instance-types $INSTANCE_TYPE |grep "VCPUINFO" |awk '{print $4}')

  MEMORY=$(aws ec2 describe-instance-types \
  --instance-types $INSTANCE_TYPE |grep "MEMORYINFO" |awk '{print $2}')

  DISK=$(aws ec2 describe-instance-types \
  --instance-types $INSTANCE_TYPE |grep "SUPPORTEDROOTDEVICETYPES" |awk '{print $2}')

  PRICE=$(aws ec2 describe-spot-price-history \
  --availability-zone $ZONE \
  --instance-types $INSTANCES \
  --product-description "Linux/UNIX" \
  --start-time $START \
  --end-time $END |awk '{print $5}')

 echo "$INSTANCE_TYPE,$VCORES,$MEMORY,$DISK,$PRICE" >> table.csv
done

rich table.csv
```


### How to Get prices:
```bash
ZONE="eu-central-1a"
INSTANCES="m6i.large"
START=$(date +%Y-%m-%dT00:00:00)
END=$(date +%Y-%m-%dT%H:%M:%S)

aws ec2 describe-spot-price-history \
--availability-zone $ZONE \
--instance-types $INSTANCES \
--product-description "Linux/UNIX" \
--start-time $START \
--end-time $END \
--output table
```

## Azure

Azure is also pretty straight-forward but you will need to do some filtering on the query results to get the data you need.

Resources:

- [Spot Prices](https://azure.microsoft.com/en-us/pricing/spot-advisor/)
- [Instance Types](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes-general)
- Nested virtualization is NOT supported on ANY of Azure's GPU VMs.

GPU VM Types:

| VM Name | CPU Name | vCores | RAM | GPU Name | GPUs | vRAM |
| ---  | --- | ---    | --- | --- | ---  | ---  |
|Standard_NC6 | Xeon E5-2690 v3 | 6 | 56 | Tesla K80 | 1 | 12 |
|Standard_NC6s_v2 | Xeon E5-2690 v4 | 6 | 112 | Tesla P100 | 1 | 16 |
|Standard_NC6s_v3 | Xeon E5-2690 v4 | 6 | 112 | Tesla V100 | 1 | 12 |
|Standard_NC4as_T4_v3 | AMD EPYC 7V12(Rome) | 4 | 28 | Tesla T4 | 1 | 16 |
|Standard_ND6s | Xeon E5-2690 v4  | 6 | 112 | Tesla P40 | 1 | 24 |
|Standard_NV6 | Xeon E5-2690 v3 | 6 | 56 | Tesla M60 | 1/2 | 8 |
|Standard_NV12s_v3 | Xeon E5-2690 v4 | 12| 112 | Tesla M60 | 0.5 | 8 |
|Standard_NV4as_v4 | AMD EPYC 7V12(Rome) | 4 | 14 | Radeon MI25 | 1/8 | 4 |
|Standard_NV6ads_A10_v5 | AMD EPYC 74F3V(Milan) | 6 | 55 | Nvidia A10 | 1/6 | 4 |

### How to Get Prices:
```bash
API_URL="https://prices.azure.com/api/retail/prices"
LOCATION="'EU West'"
SERVICE_NAME="'Virtual Machines'"
SERVICE_FAMILY="'Compute'"
ARM_SKU="Standard_D8d_v4"
METER_NAME=$(echo "'$ARM_SKU Spot'"| sed 's/Standard_//g' |sed 's/_/ /g')
ARM_SKU_NAME=$(echo "'$ARM_SKU'")

echo "az rest --method get --uri \"${API_URL}?\\\$filter=\
location eq $LOCATION and \
serviceName eq $SERVICE_NAME and \
serviceFamily eq $SERVICE_FAMILY and \
armSkuName eq $ARM_SKU_NAME and \
meterName eq $METER_NAME"\" \
--query \"[Items][0][*].{Name:productName, SKU:armSkuName, Location:location, Price:retailPrice}\" \
-o table |bash |grep -v Windows

```

## Equinix Spot Metal

Equinix isnt a cloud-provider so much as a colocation service with a good set of APIs. They dont have a fancy cli so you just query an API endpoint and get back a json file that basically already in the format we want anyway.

Resources
- [Metros](https://metal.equinix.com/developers/docs/locations/metros/)
- [Instance types](https://metal.equinix.com/product/servers/)

### How to Get Prices
```bash
TOKEN=""
URL="https://api.equinix.com/metal/v1/market/spot/prices/metros"
METRO="am"

PRICES=$(curl -X GET -H "X-Auth-Token: $TOKEN" $URL -d "metro=$METRO" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['spot_market_prices']['am'])"| sed "s/'/\"/g") && \
echo $PRICES > prices.json && \
rich prices.json
```

## Google Cloud Platform

Google is the worst when it comes to transparancy around what exact CPU you will get when you request a VM from them.
UNless you want the NEWEST (A2 - Cascade lake), you could get ANY cpu from a mix of old to really old CPUs.
The fact that the only GPU capable SKU's are the N1 (random cpu) or A2 (cascade lake) means I can't really give an accurate CPU model or date.

- https://www.densify.com/articles/google-compute-engine-machine-types

GCP is also frustrating because we have to put in a LOT of boilerplate to get the data we want. Since GCP doesnt use machine families the same way others do, we have to get the individual prices of the CPU type, RAM amount, and GPU type that we will use in the VM. Once we have all these data-points we can create a final price.

### How to get Prices

1. have an existing project (an organzation alone isnt enough)
2. Enable the Cloud Billing API: https://console.cloud.google.com/flows/enableapi?apiid=cloudbilling.googleapis.com
3. Create an API key: https://cloud.google.com/docs/authentication/api-keys

Create an API key using the gcloud CLI

```bash
gcloud alpha services api-keys create --display-name=SOME_NAME
```

Get price per CPU core

```bash

# JQ explanation
# 1. set the REGION arg to an array represented as a string - required to check multiple regions
# 2. filter results for items in the desired regions. uses 'index' because we need to find an item in a nested array
# 3. filter for items priced by the hour 'h'. This removes reserved instances from results
# 4. filter based on the `resourceGroups` filed which is poorly named. It's closer to `family` or `machine type` from other cloud providers.
# 5. filter usage types for Preemptable only, you could also filter for OnDemand type instances.
# 6. Check if the description contains the GPU type we want. This data is oddly not in its own filed anywhere.

curl https://cloudbilling.googleapis.com/v1/services/6F81-5844-456A/skus?key=$(bw get notes "GCP API key") > skus_compute_engine.json

export FAMILY="N1Standard" # or `CPU`
export REGION='"europe-west1", "europe-west4", "europe-central2"'
export CORES="16"
export CPU_TIER="N1" # or A2 

DATA=$(cat skus_compute_engine.json \
  | jq -r --arg REGION "$REGION" '.skus[] 
  | select((.serviceRegions | index( '"$REGION"' )) 
  and select(.pricingInfo[0].pricingExpression.usageUnit=="h") 
  and .category.resourceGroup==env.FAMILY 
  and .category.usageType=="Preemptible" 
  and select(.description | contains( env.CPU_TIER )))')

export NANOS=$(echo $DATA |jq '.pricingInfo[0].pricingExpression.tieredRates[0].unitPrice.nanos')
CONVERTED_RATE=$(bc <<< "scale=5; $NANOS/1000000000")
CPU_PRICE=$( bc <<< "scale=5; $CONVERTED_RATE * $CORES" )
echo "CPU Price: $CPU_PRICE"
```

Get RAM price:

```bash
export FAMILY="N1Standard" # or `RAM`
export REGION='"europe-west1", "europe-west4"'
export RAM_AMOUNT="64"
export CPU_TIER="N1"

DATA=$(cat skus_compute_engine.json \
  | jq -r --arg REGION "$REGION" '.skus[] 
  | select((.serviceRegions | index( '"$REGION"' )) 
  and select(.pricingInfo[0].pricingExpression.usageUnit=="GiBy.h") 
  and .category.resourceGroup==env.FAMILY 
  and .category.usageType=="Preemptible" 
  and select(.description | contains( env.CPU_TIER )))')

export NANOS=$(echo $DATA |jq '.pricingInfo[0].pricingExpression.tieredRates[0].unitPrice.nanos')
CONVERTED_RATE=$(bc <<< "scale=5; $NANOS/1000000000")
RAM_PRICE=$( bc <<< "scale=5; $CONVERTED_RATE * $RAM_AMOUNT" )
echo "RAM Price: $RAM_PRICE"
```

Get price per GPU

```bash
# JQ explanation
# 1. set the REGION arg to an array represented as a string - required to check multiple regions
# 2. filter results for items in the desired regions. uses 'index' because we need to find an item in a nested array
# 3. filter for items priced by the hour 'h'. This removes reserved instances from results
# 4. filter based on the `resourceGroupz filed which is poorly named. It's closer to 'family' or 'machine type' from other cloud providers.
# 5. filter usage types for Preemptable only, you could also filter for OnDemand type instances.
# 6. Check if the description contains the GPU type we want. This data is oddly not in its own filed anywhere.

GPU Types: T4, P4, A100, P100

export FAMILY="GPU"
export GPU_TYPE="T4"
export GPUS=1
export REGION='"europe-west1", "europe-west4"'

DATA=$(cat skus_compute_engine.json \
  | jq -r --arg REGION "$REGION" '.skus[] 
  | select((.serviceRegions | index( '"$REGION"' )) 
  and select(.pricingInfo[0].pricingExpression.usageUnit=="h") 
  and .category.resourceGroup==env.FAMILY 
  and .category.usageType=="Preemptible" 
  and select(.description | contains( env.GPU_TYPE )))')


export NANOS=$(echo $DATA \
  |jq '.pricingInfo[0].pricingExpression.tieredRates[0].unitPrice.nanos')

CONVERTED_RATE=$(bc <<< "scale=5; $NANOS/1000000000")

GPU_PRICE=$( bc <<< "scale=5; $CONVERTED_RATE * $GPUS" )

echo "GPU Price: $GPU_PRICE"
```

Combine prices

```bash
COMBINED_PRICE=$(bc <<< "scale=5; $CPU_PRICE + $RAM_PRICE + $GPU_PRICE")
echo "Combined Price: $COMBINED_PRICE"
```


## Chart Rough Draft

|Vendor |Name           |CPU Name                 |CPU Date|vCPU|MEM|DISK |Price/hr|
|-------|---------------|-------------------------|--------|----|---|-----|--------|
|GCP    |c2d-highcpu-2  |Zen3 AMD EPYC Milan      |Q1-2021 |2   |4  |???  |$0.0198 |
|GCP    |c2d-highcpu-4  |Zen3 AMD EPYC Milan      |Q1-2021 |4   |8  |???  |$0.0396 |
|Azure  |Standard_D4d_v4|Xeon Platinum 8272CL     |Q2-2019 |4   |16 |150  |$0.04   |
|GCP    |c2d-standard-4 |Zen3 AMD EPYC Milan      |Q1-2021 |4   |16 |???  |$0.04796|
|GCP    |c2-standard-4  |3.9 GHz Cascade Lake Xeon|Q1-2020 |4   |16 |???  |$0.0557 |
|GCP    |c2d-highcpu-8  |Zen3 AMD EPYC Milan      |Q1-2021 |8   |16 |???  |$0.0792 |
|Azure  |Standard_D8d_v4|Xeon Platinum 8272CL     |Q2-2019 |8   |32 |300  |$0.08   |
|Equinix|m3.small.x86   |Rocket Lake Xeon E-2378G |Q3-2021 |16  |64 |960  |$0.11   |
|AWS    |M6i.large      |Xeon Ice Lake 8375C      |Q2-2020 |2   |8  |???  |$0.113  |
|AWS    |M6a.large      |AMD EPYC 7R13 Zen3       |Q1-2021 |2   |8  |???  |$0.113  |
|GCP    |c2-standard-8  |3.9 GHz Cascade Lake Xeon|Q1-2020 |8   |32 |???  |$0.1114 |
|AWS    |M6i.xlarge     |Xeon Ice Lake 8375C      |Q2-2020 |4   |16 |???  |$0.2259 |
|AWS    |M6a.xlarge     |AMD EPYC 7R13 Zen3       |Q1-2021 |4   |16 |???  |$0.2259 |
|Equinix|n3.xlarge.x86  |Xeon Gold 6314U Ice Lake |Q2-2021 |64  |512|7.6TB|$0.45   |
|AWS    |M6i.2xlarge    |Xeon Ice Lake 8375C      |Q2-2020 |8   |32 |???  |$0.4518 |
|AWS    |M6a.2xlarge    |AMD EPYC 7R13 Zen3       |Q1-2021 |8   |32 |???  |$0.4518 |
|Equinix|a3.xlarge.x86  |2 x Xeon Gold 6338       |Q2-2021 |128 |1TB|480GB|$0.75   |
