FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 python3-venv python3-pip supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
COPY docker/app/requirements.txt /opt/app/requirements.txt
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 \
        -r /opt/app/requirements.txt

COPY docker/app/ /opt/app/
COPY docker/supervisord.conf /etc/supervisor/conf.d/ctf.conf
COPY docker/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

RUN useradd -m -s /bin/bash dockworker
# Linux capability misconfig (Stage 10's privesc): grant python3 the
# ability to set any uid, same as a CTF-standard `setcap cap_setuid+ep`
# misconfiguration seen in the wild.
RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq libcap2-bin \
    && rm -rf /var/lib/apt/lists/* \
    && REAL_PY=$(readlink -f /usr/bin/python3) \
    && setcap cap_setuid+ep "$REAL_PY" \
    && getcap "$REAL_PY"

EXPOSE 5000
# Port 5001 (the internal diagnostics API) is intentionally NEVER
# published here or in docker-compose.yml -- reachable only via the
# main app's SSRF-vulnerable /preview endpoint, from inside the container.

ENTRYPOINT ["/opt/entrypoint.sh"]
