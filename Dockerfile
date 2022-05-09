#Use supplier image
FROM docker.io/ubuntu:focal

LABEL org.opencontainers.image.source=https://github.com/libre-devops/azure-terraform-gh-action

#Set args with blank values - these will be over-written with the CLI
ARG ACCEPT_EULA="y"
ARG NORMAL_USER=ldo
ARG DEBIAN_FRONTEND=noninteractive

ENV ACCEPT_EULA ${ACCEPT_EULA}
ENV NORMAL_USER ${NORMAL_USER}
ENV DEBIAN_FRONTEND=noninteractive

#Declare user expectation, I am performing root actions, so use root.
USER root

#Install needed packages as well as setup python with args and pip
RUN mkdir -p /ldo && \
    #Make unpriviledged user
    useradd -ms /bin/bash ${NORMAL_USER} && \
    chown -R ${NORMAL_USER} /ldo && \
    apt-get update -y && apt-get dist-upgrade -y && apt-get install -y \
    apt-transport-https \
    bash \
    libbz2-dev \
    ca-certificates \
    curl \
    gcc \
    git  \
    gnupg \
    gnupg2 \
    libffi-dev \
    libicu-dev \
    make \
    software-properties-common \
    libsqlite3-dev \
    libssl-dev\
    unzip \
    wget \
    zip  \
    zlib1g-dev && \
                useradd -m -s /bin/bash linuxbrew && \
                usermod -aG sudo linuxbrew &&  \
                mkdir -p /home/linuxbrew/.linuxbrew && \
                chown -R linuxbrew: /home/linuxbrew/.linuxbrew && \
    wget -q https://packages.microsoft.com/config/ubuntu/$(grep -oP '(?<=^DISTRIB_RELEASE=).+' /etc/lsb-release | tr -d '"')/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb  && rm -rf packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell

RUN echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list && \
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/Release.key" | apt-key add - && \
apt-get update && \
apt-get -y upgrade && \
apt-get -y install container-tools && \
apt-get install -y crun podman fuse-overlayfs

RUN curl -s "https://get.sdkman.io" | bash

RUN useradd podman; \
echo podman:10000:5000 > /etc/subuid; \
echo podman:10000:5000 > /etc/subgid;

VOLUME /var/lib/containers
RUN mkdir -p /home/podman/.local/share/containers
RUN chown podman:podman -R /home/podman && usermod -aG podman ${NORMAL_USER}
VOLUME /home/podman/.local/share/containers

#https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf
ADD containers.conf /etc/containers/containers.conf
#https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf
ADD podman-containers.conf /home/podman/.config/containers/containers.conf

ADD storage.conf /etc/containers/storage.conf

#chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /etc/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; \
    touch /var/lib/shared/overlay-images/images.lock; \
    touch /var/lib/shared/overlay-layers/layers.lock; \
    touch /var/lib/shared/vfs-images/images.lock; \
    touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

#Prepare container for Azure DevOps script execution
WORKDIR /ldo

#Set as unpriviledged user for default container execution
USER linuxbrew

RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/linuxbrew/.bash_profile && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/linuxbrew/.bashrc && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    curl -s "https://get.sdkman.io" | bash && \
    brew install cowsay

USER root
RUN sudo chown -R ${NORMAL_USER} /home/linuxbrew/.linuxbrew

USER ${NORMAL_USER}
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/${NORMAL_USER}/.bash_profile && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/${NORMAL_USER}/.bashrc && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    curl -s "https://get.sdkman.io" | bash && \
    brew install cowsay

USER root

#Set User Path with expected paths for new packages
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin:/usr/local/go:/usr/local/go/dev/bin:/usr/local/bin/python3:/home/linuxbrew/.linuxbrew/bin:/home/${NORMAL_USER}/.local/bin:${PATH}"
RUN echo $PATH > /etc/environment

#Install User Packages
RUN echo 'alias powershell="pwsh"' >> /home/${NORMAL_USER}/.bashrc && \
    echo 'alias powershell="pwsh"' >> /root/.bashrc

COPY entrypoint.sh /home/${NORMAL_USER}/entrypoint.sh
RUN chmod +rx /home/${NORMAL_USER}/entrypoint.sh

USER ${NORMAL_USER}

RUN brew install tfsec python3 terraform azure-cli
RUN pip3 install --user terraform-compliance checkov

WORKDIR /home/${NORMAL_USER}
ENTRYPOINT entrypoint.sh
