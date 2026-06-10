FROM ubuntu:22.04

ARG CANN_VERSION=8.5.0
ARG CHIP=910b
ARG ASCEND_BASE_URL=https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/CANN/CANN%208.5.0

ENV DEBIAN_FRONTEND=noninteractive
ENV ASCEND_INSTALL_PATH=/usr/local/Ascend

RUN sed -i 's|http://ports.ubuntu.com/ubuntu-ports|http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports|g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    file \
    g++ \
    gcc \
    gdb \
    git \
    make \
    cmake \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    wget \
    vim \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple \
    attrs \
    cython \
    numpy \
    decorator \
    sympy \
    cffi \
    pyyaml \
    pathlib2 \
    psutil \
    protobuf==3.20.0 \
    scipy \
    requests \
    absl-py

WORKDIR /tmp/cann-install

RUN wget -q --show-progress -O Ascend-cann-toolkit_${CANN_VERSION}_linux-aarch64.run \
    ${ASCEND_BASE_URL}/Ascend-cann-toolkit_${CANN_VERSION}_linux-aarch64.run \
    && bash Ascend-cann-toolkit_${CANN_VERSION}_linux-aarch64.run --install --quiet \
    && rm -f Ascend-cann-toolkit_${CANN_VERSION}_linux-aarch64.run

RUN wget -q --show-progress -O Ascend-cann-${CHIP}-ops_${CANN_VERSION}_linux-aarch64.run \
    ${ASCEND_BASE_URL}/Ascend-cann-${CHIP}-ops_${CANN_VERSION}_linux-aarch64.run \
    && bash Ascend-cann-${CHIP}-ops_${CANN_VERSION}_linux-aarch64.run --install --quiet \
    && rm -f Ascend-cann-${CHIP}-ops_${CANN_VERSION}_linux-aarch64.run

RUN printf '%s\n' \
    'if [ -f /usr/local/Ascend/cann-8.5.0/set_env.sh ]; then source /usr/local/Ascend/cann-8.5.0/set_env.sh; fi' \
    'if [ -f /usr/local/Ascend/ascend-toolkit/set_env.sh ]; then source /usr/local/Ascend/ascend-toolkit/set_env.sh; fi' \
    'if [ -f /usr/local/Ascend/cann/set_env.sh ]; then source /usr/local/Ascend/cann/set_env.sh; fi' \
    'if [ -f /usr/local/Ascend/nnal/atb/set_env.sh ]; then source /usr/local/Ascend/nnal/atb/set_env.sh; fi' \
    > /etc/profile.d/ascend.sh

WORKDIR /workspace

CMD ["/bin/bash", "-l"]
