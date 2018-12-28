# Introduction 

This tutorial offers a simple way to build Tensorflow Serving binaries on Centos7 with needed libraries.

*Disclaimer:*

This page has been wrote to build tensorflow_model_server for GPU nodes with following libraries: 
- nccl : 2.3.5
- cuda : 9.2 
- cudnn : 7.1.4

Other versions have not been tested. 

## Requirements

Few requirements are needed to follow this tutorial, however here are the tools you'll need : 
  - Docker ( tutorial wrote with version 18.06.1-ce )
  - Bash

## 1. Downloading libraries 

To build Tensorflow with GPU, you need to have **nccl** and **cudnn** libraries available.

### a. CUDNN 

cudnn is accessible by this script : 
```bash 
wget http://developer.download.nvidia.com/compute/redist/cudnn/v7.1.4/cudnn-9.2-linux-x64-v7.1.tgz
```

Other version of cudnn are accessible https://developer.nvidia.com/rdp/cudnn-archive

### b. NCCL

nccl unfortunately does not provide any public url to download the libraries. You'll have to 
create a NVIDIA developper account then go this https://developer.nvidia.com/nccl/nccl2-download-survey. 

The version of nccl used in this tutorial is `nccl_2.3.5-2+cuda9.2_x86_64`

## 2. Editing the Dockerfile 

The whole building process is (almost) fully automated in a `Dockerfile`, however you'll to update the header of the file provided to match your libraries version. 

By looking at the head of the `Dockerfile`, you'll see :

```
# Things to edit
ENV TF_CUDA_VERSION=9.2
ENV TF_CUDNN_VERSION=7
ENV TF_NCCL_VERSION=2

ENV NCCL_VERSION=2.3.5
ENV CUDNN_VERSION=7.1.4
ENV NCCL_SRC=/nccl/nccl_2.3.5-2+cuda9.2_x86_64


WORKDIR /
ADD nccl_2.3.5-2+cuda9.2_x86_64.txz nccl
ADD cudnn-9.2-linux-x64-v7.1.tgz cudnn
# end of the things to edit
```

Edit this variables to make them match the versions you've just downloaded. Once you've done this, you'll be ready to run. 

### 3. Building 

Run the following command to start the building process : 

```
docker build -f ./Dockerfile -t $NAME_OF_YOUR_IMAGE:$VERSION .
```

### 4. Getting the executable

Finally launch this command to get the **model_server** executable, it will be available in **your current directory**:  

```
CONTAINER=$(docker create tensorflow-serving-gpu) && docker cp $CONTAINER:/usr/local/bin/tensorflow_model_server . && docker rm $CONTAINER
```

### 5. Have fun with Tensorflow Serving runnning on your GPUs ! 

 
