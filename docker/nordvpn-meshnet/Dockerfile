FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg iproute2 iptables nftables procps \
    && curl -sSf https://repo.nordvpn.com/gpg/nordvpn_public.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/nordvpn.gpg \
    && echo "deb https://repo.nordvpn.com/deb/nordvpn/debian stable main" > /etc/apt/sources.list.d/nordvpn.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nordvpn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
