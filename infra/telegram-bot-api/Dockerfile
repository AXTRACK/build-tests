FROM ubuntu:24.04 AS build

ARG TELEGRAM_BOT_API_COMMIT=e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1
ARG BUILD_JOBS=2

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates cmake g++ git gperf libssl-dev make zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/tdlib/telegram-bot-api.git . \
    && git checkout "${TELEGRAM_BOT_API_COMMIT}" \
    && git submodule update --init --recursive

RUN cmake -S . -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/telegram-bot-api \
    && cmake --build build --target install --parallel "${BUILD_JOBS}" \
    && strip /opt/telegram-bot-api/bin/telegram-bot-api

FROM ubuntu:24.04 AS runtime

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates libssl3t64 zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 telegram \
    && useradd --system --uid 10001 --gid 10001 --home-dir /var/lib/telegram-bot-api --shell /usr/sbin/nologin telegram \
    && mkdir -p /var/lib/telegram-bot-api /tmp/telegram-bot-api \
    && chown -R telegram:telegram /var/lib/telegram-bot-api /tmp/telegram-bot-api

COPY --from=build /opt/telegram-bot-api/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

USER telegram
VOLUME ["/var/lib/telegram-bot-api"]
EXPOSE 8081 8082
ENTRYPOINT ["/usr/local/bin/telegram-bot-api"]
CMD ["--local", "--http-port=8081", "--http-stat-port=8082", "--dir=/var/lib/telegram-bot-api", "--files-dir=/var/lib/telegram-bot-api", "--temp-dir=/tmp/telegram-bot-api", "--verbosity=1"]
