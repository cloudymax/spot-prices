# Spot Pricing Notes

These are just my notes, check out https://cloudoptimizer.io/ for a real implimentation 
## AWS

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


How to Get prices:
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

Resources:

- [Spot Prices](https://azure.microsoft.com/en-us/pricing/spot-advisor/)
- [Instance Types](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes-general)

How to Get Prices:
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

Resources
- [Metros](https://metal.equinix.com/developers/docs/locations/metros/)
- [Instance types](https://metal.equinix.com/product/servers/)

How to Get Prices
```bash
TOKEN=""
URL="https://api.equinix.com/metal/v1/market/spot/prices/metros"
METRO="am"

PRICES=$(curl -X GET -H "X-Auth-Token: $TOKEN" $URL -d "metro=$METRO" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['spot_market_prices']['am'])"| sed "s/'/\"/g") && \
echo $PRICES > prices.json && \
rich prices.json
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
