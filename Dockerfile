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
    sudo \
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
                chown -R linuxbrew: /home/linuxbrew/.linuxbrew

WORKDIR /ldo

USER linuxbrew

RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/linuxbrew/.bash_profile && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/linuxbrew/.bashrc && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew install cowsay

USER root
RUN sudo chown -R ${NORMAL_USER} /home/linuxbrew/.linuxbrew && \
    chmod

USER ${NORMAL_USER}
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/${NORMAL_USER}/.bash_profile && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/${NORMAL_USER}/.bashrc && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew install cowsay

USER root

#Set User Path with expected paths for new packages
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin:/usr/local/go:/usr/local/go/dev/bin:/usr/local/bin/python3:/home/linuxbrew/.linuxbrew/bin:/home/${NORMAL_USER}/.local/bin:${PATH}"
RUN echo $PATH > /etc/environment

#Install User Packages
RUN echo 'alias powershell="pwsh"' >> /home/${NORMAL_USER}/.bashrc && \
    echo 'alias powershell="pwsh"' >> /root/.bashrc

COPY entrypoint.sh /ldo/entrypoint.sh
RUN chmod 777 -R /ldo

USER ${NORMAL_USER}

RUN brew install tfsec python3 terraform azure-cli
RUN pip3 install --user terraform-compliance checkov

WORKDIR /ldo
ENTRYPOINT ["/ldo/entrypoint.sh"]
