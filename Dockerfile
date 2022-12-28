FROM ubuntu:latest


RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y python3 \
    python3-pip \
    gnupg \
    software-properties-common \
    wget \
    curl \
    zip \
    gettext-base \
    whois \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    gnupg

RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc |gpg --dearmor |tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

RUN AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=`dpkg --print-architecture`] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |tee /etc/apt/sources.list.d/azure-cli.list

RUN apt-get update && apt-get install -y azure-cli

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" |tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg |tee /usr/share/keyrings/cloud.google.gpg

RUN apt-get update && apt-get install google-cloud-cli
