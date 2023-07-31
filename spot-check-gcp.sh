#!/bin/bash

get_all_sku_data(){
  DONE="false"
  PAGE=0

  #echo "Downloading price data from GCP..." >&3
  curl -sS https://cloudbilling.googleapis.com/v1/services/6F81-5844-456A/skus?key=$(bw get notes "GCP API key") > "skus_compute_engine_page_$PAGE.json"
  #echo "Page0 ✅" >&3

  until [ "$DONE" == "true" ]
  do
      TOKEN=$(cat skus_compute_engine_page_${PAGE}.json |jq -r '.nextPageToken')
      if [ -z "$TOKEN" ]; then
          export DONE="true"
      else
          let PAGE++
          curl "https://cloudbilling.googleapis.com/v1/services/6F81-5844-456A/skus?key=$(bw get notes "GCP API key")&pageToken=$TOKEN" > "skus_compute_engine_page_$PAGE.json"
          #echo "Page${PAGE} ✅" >&3
      fi
  done

  #echo "Combining data..."
  jq -n '{ skus: [ inputs.skus ]  | add }' skus_compute_engine_page_0.json skus_compute_engine_page_1.json > data.json
  jq -n '{ skus: [ inputs.skus ]  | add }' data.json skus_compute_engine_page_2.json > data0.json
  jq -n '{ skus: [ inputs.skus ]  | add }' data0.json skus_compute_engine_page_3.json > data1.json

  #echo "Cleaning Up..."
  mv data1.json all-assets.json
  rm skus_compute_engine_page*
  rm data*.json
}

get_cpu_price(){
    #echo "Getting price of CPU..."
    DATA=$(cat all-assets.json \
        | jq -r --arg REGION "$REGION" '.skus[]
        | select((.serviceRegions | index( '"$REGION"' ))
        and select(.pricingInfo[0].pricingExpression.usageUnit=="h")
        and .category.resourceGroup==env.FAMILY
        and .category.usageType=="Preemptible"
        and select(.description | contains( env.CPU_TIER )))')

    NANOS=$(echo $DATA |jq \
        '.pricingInfo[0].pricingExpression.tieredRates[0].unitPrice.nanos')

    CONVERTED_RATE=$( bc <<< "scale=5; $NANOS/1000000000" )
    export CPU_PRICE=$(bc <<< "scale=5; $CONVERTED_RATE * $CPU_CORES")
    #echo "CPU Price: $CPU_PRICE"
}

get_memory_price(){
    #echo "Getting price of RAM..."
    DATA=$(cat all-assets.json \
        | jq -r --arg REGION "$REGION" '.skus[]
        | select((.serviceRegions | index( '"$REGION"' ))
        and select(.pricingInfo[0].pricingExpression.usageUnit=="GiBy.h")
        and .category.resourceGroup==env.INSTANCE_FAMILY
        and .category.usageType=="Preemptible"
        and select(.description | contains( env.CPU_TIER )))')

    NANOS=$(echo $DATA |jq '.pricingInfo[0].pricingExpression.tieredRates[0].unitPrice.nanos')
    CONVERTED_RATE=$(bc <<< "scale=5; $NANOS/1000000000")
    export RAM_PRICE=$( bc <<< "scale=5; $CONVERTED_RATE * $RAM_AMOUNT" )
    #echo "RAM Price: $RAM_PRICE"
}

get_gpu_price(){
    #echo "Getting GPU price..."
    DATA=$(cat all-assets.json \
        | jq -r --arg REGION "$REGION" '.skus[]
        | select((.serviceRegions | index( '"$REGION"' ))
        and select(.pricingInfo[0].pricingExpression.usageUnit=="h")
        and .category.resourceGroup=="GPU"
        and .category.usageType=="Preemptible"
        and select(.description | contains( env.GPU_TYPE )))')

        NANOS=$(echo $DATA |jq '.pricingInfo[0].pricingExpression.tieredRates[0].unitPrice.nanos')
        CONVERTED_RATE=$(bc <<< "scale=5; $NANOS/1000000000")
        export GPU_PRICE=$( bc <<< "scale=5; $CONVERTED_RATE * $GPUS" )
        #echo "GPU Price: $GPU_PRICE"
}


all_gpu_types(){
    #echo "Getting GPU Types..."
    DATA=$(cat all-assets.json   | jq -r --arg REGION "$REGION" '.skus[]
        | select((.serviceRegions | index( '"$REGION"' ))
        and select(.pricingInfo[0].pricingExpression.usageUnit=="h")
        and .category.resourceGroup=="GPU"
        and .category.usageType=="Preemptible")' |jq '.description')
        echo "$DATA"
}

combined_price(){
    COMBINED_PRICE=$(bc <<< "scale=5; $CPU_PRICE + $RAM_PRICE + $GPU_PRICE")

    RESPONSE=$(jq --null-input \
        --arg instance "$INSTANCE_FAMILY" \
        --arg vcores "$CPU_CORES" \
        --arg cpu_tier "$CPU_TIER" \
        --arg memory "$RAM_AMOUNT" \
        --arg gpus "$GPUS" \
        --arg gpu_type "$GPU_TYPE" \
        --arg cpu_price "$CPU_PRICE" \
        --arg memory_price "$RAM_PRICE" \
        --arg gpu_price "$GPU_PRICE" \
        --arg combined_price "$COMBINED_PRICE" \
        '{"instance": $instance,
            "vcores": $vcores,
            "cpu_tier": $cpu_tier,
            "memory": $memory,
            "gpus": $gpus,
            "gpu_type": $gpu_type,
            "cpu_price": $cpu_price,
            "memory_price": $memory_price,
            "gpu_price": $gpu_price,
            "combined_price": $combined_price}')

    echo $RESPONSE
}

get(){
    export INSTANCE_FAMILY="N1Standard"
    export REGION='"europe-west4"'
    export CPU_CORES="8"
    export CPU_TIER="N1"
    export RAM_AMOUNT="16"
    export GPU_TYPE="T4"
    export GPUS=1

    get_cpu_price
    get_memory_price
    get_gpu_price
    combined_price
}

"$@"
