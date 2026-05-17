FROM ghcr.io/wesm/agentsview:0.29.0

COPY dot_config/agentsview/fly-entrypoint.sh /usr/local/bin/fly-entrypoint.sh
RUN chmod 0755 /usr/local/bin/fly-entrypoint.sh

ENV AGENTSVIEW_DATA_DIR=/data
ENV AGENTSVIEW_DISABLE_UPDATE_CHECK=1

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/fly-entrypoint.sh"]
