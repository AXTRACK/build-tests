FROM ubuntu:24.04

ARG TUNNEL_CLIENT_VERSION=v0.0.15
ARG TUNNEL_CLIENT_SHA256=8c836dc5d68d68b663d9a5c5b28ff9fa780d9f7a3fffb1c306880b8f32fab5f1

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/tunnel-client.zip \
      "https://github.com/openai/tunnel-client/releases/download/${TUNNEL_CLIENT_VERSION}/tunnel-client-${TUNNEL_CLIENT_VERSION}-linux-amd64.zip" \
    && echo "${TUNNEL_CLIENT_SHA256}  /tmp/tunnel-client.zip" | sha256sum -c - \
    && mkdir -p /opt/tunnel-client \
    && unzip -q /tmp/tunnel-client.zip -d /opt/tunnel-client \
    && rm /tmp/tunnel-client.zip \
    && chmod +x /opt/tunnel-client/tunnel-client

RUN useradd --system --uid 10002 --create-home --home-dir /home/tunnel tunnel \
    && mkdir -p /data/profiles /data/logs \
    && chown -R tunnel:tunnel /data /home/tunnel

USER tunnel
VOLUME ["/data"]
WORKDIR /data

ENTRYPOINT ["/opt/tunnel-client/tunnel-client"]
CMD ["help", "quickstart"]
