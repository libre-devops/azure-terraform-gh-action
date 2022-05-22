#Use own image
FROM ghcr.io/libre-devops/azure-terraform-gh-action-base:latest

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
