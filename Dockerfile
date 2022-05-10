#Use own image
FROM ghcr.io/libre-devops/azure-terraform-gh-action-base:latest

LABEL org.opencontainers.image.source=https://github.com/libre-devops/azure-terraform-gh-action

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
