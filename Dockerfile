#Use own image
FROM ghcr.io/libre-devops/azure-terraform-gh-action-base:latest

LABEL org.opencontainers.image.source=https://github.com/libre-devops/azure-terraform-gh-action

#Set args with blank values - these will be over-written with the CLI
ARG ACCEPT_EULA="y"
ARG NORMAL_USER=ldo
ARG DEBIAN_FRONTEND=noninteractive

ENV ACCEPT_EULA ${ACCEPT_EULA}
ENV NORMAL_USER ${NORMAL_USER}
ENV DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /
COPY entrypoint.sh entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
