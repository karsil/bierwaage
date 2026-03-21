FROM grafana/grafana:latest-ubuntu
USER root
RUN apt-get update -qq && apt-get install -y --no-install-recommends unzip \
    && curl -Lo /tmp/plugin.zip \
    https://github.com/motherduckdb/grafana-duckdb-datasource/releases/download/v0.4.1/motherduck-duckdb-datasource-0.4.1.zip \
    && unzip /tmp/plugin.zip -d /var/lib/grafana/plugins/ \
    && rm /tmp/plugin.zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
USER grafana
