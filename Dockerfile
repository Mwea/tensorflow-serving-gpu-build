FROM nvidia/cuda:9.2-base-centos7

ARG TF_SERVING_VERSION_GIT_BRANCH=master
ARG TF_SERVING_VERSION_GIT_COMMIT=head

LABEL maintainer=gvasudevan@google.com
LABEL tensorflow_serving_github_branchtag=${TF_SERVING_VERSION_GIT_BRANCH}
LABEL tensorflow_serving_github_commit=${TF_SERVING_VERSION_GIT_COMMIT}

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

# Install needed dependencies for building
RUN yum group install -y "Development Tools"
RUN yum install -y which
RUN yum install -y java-1.8.0-openjdk-devel
RUN yum install -y cuda-command-line-tools-9-2 \
        cuda-cublas-dev-9-2 \
        cuda-cudart-dev-9-2 \
        cuda-cufft-dev-9-2 \
        cuda-curand-dev-9-2 \
        cuda-cusolver-dev-9-2 \
        cuda-cusparse-dev-9-2

# Install bazel
ENV BAZEL_VERSION 0.15.0
WORKDIR /
RUN mkdir /bazel && \
    cd /bazel && \
    curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE && \
    chmod +x bazel-*.sh && \
    ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    cd / && \
    rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh


RUN cp /cudnn/cuda/lib64/* /usr/local/cuda/lib64/
RUN cp /cudnn/cuda/include/* /usr/local/cuda/include/
RUN cp /cudnn/cuda/include/* /usr/include/

# Download TF Serving sources (optionally at specific commit).
WORKDIR /tensorflow-serving
RUN git clone --branch=${TF_SERVING_VERSION_GIT_BRANCH} https://github.com/tensorflow/serving . && \
    git remote add upstream https://github.com/tensorflow/serving.git && \
    if [ "${TF_SERVING_VERSION_GIT_COMMIT}" != "head" ]; then git checkout ${TF_SERVING_VERSION_GIT_COMMIT} ; fi

# # Build TensorFlow with the CUDA configuration
ENV CI_BUILD_PYTHON python
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH
ENV TF_NEED_CUDA 1
ENV TF_CUDA_COMPUTE_CAPABILITIES=3.0,3.5,5.2,6.0,6.1,7.0
ENV TF_TENSORRT_VERSION=4.1.2

# NCCL 2.x
ENV NCCL_INSTALL_PATH=/usr/lib/
ENV NCCL_HDR_PATH=/usr/include

# This is needed so tensorflow can use it during the build
RUN mkdir -p ${NCCL_INSTALL_PATH} && \
  ln -s ${NCCL_SRC}/include/nccl.h /usr/include/nccl.h && \
  ln -s ${NCCL_SRC}/lib/libnccl.so /usr/lib/libnccl.so && \
  ln -s ${NCCL_SRC}/lib/libnccl.so.${TF_NCCL_VERSION} /usr/lib/libnccl.so.${TF_NCCL_VERSION}

ENV TMP="/tmp"

WORKDIR /tensorflow-serving

# Build, and install TensorFlow Serving
ENV TF_SERVING_BUILD_OPTIONS="--copt=-march=native --copt=-fPIC --cxxopt=-fPIC --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0"
ENV TF_SERVING_BAZEL_OPTIONS=""

ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH}

RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
  ldconfig && \
  bazel build -c opt --color=yes --curses=yes --config=cuda \
  ${TF_SERVING_BAZEL_OPTIONS} \
  --verbose_failures \
  --output_filter=DONT_MATCH_ANYTHING \
  ${TF_SERVING_BUILD_OPTIONS} \
  tensorflow_serving/model_servers:tensorflow_model_server

RUN cp bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server /usr/local/bin/
