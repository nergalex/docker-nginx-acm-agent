ARG RELEASE=bookworm
FROM debian:${RELEASE}-slim as nginx-installer

LABEL maintainer="F5 SE"

# Define NGINX versions for NGINX Plus and NGINX Plus modules
ARG NGINX_AGENT_VERSION=3.3.2~bookworm
# ARG CONTROLLER_HOST
# ARG INSTANCE_GROUP

# create nginx user/group first, to be consistent throughout docker variants
# RUN addgroup --system nginx || true \
#     && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false nginx || true

# Install prerequisite packages
RUN  apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        ca-certificates \
                        gnupg1 \
                        lsb-release \
                        curl \
                        sudo \
                        vim  \
                        procps  \
                        gnupg  \
                        binutils  \
                        net-tools  \
                        jq  \
                        tcpdump \
                        apt-utils \
                        apt-transport-https \
                        distro-info-data \
                        gettext-base \
                        brotli \
                        wget \
                        git \
                        libxml2 \
                        gettext-base \
                        gnupg2 \
                        debian-archive-keyring \
                        dnsutils \
                        iproute2 \
                        inotify-tools

# Download and add the NGINX signing keys:
RUN wget -qO - https://cs.nginx.com/static/keys/nginx_signing.key | \
    gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
RUN wget -qO - https://cs.nginx.com/static/keys/app-protect-security-updates.key | \
    gpg --dearmor | tee /usr/share/keyrings/app-protect-security-updates.gpg >/dev/null

# Add NGINX Plus repository:
RUN printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" | \
    tee /etc/apt/sources.list.d/nginx-plus.list

# Add NGINX App Protect WAF repositories:
RUN printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    https://pkgs.nginx.com/app-protect/debian `lsb_release -cs` nginx-plus\n" | \
    tee /etc/apt/sources.list.d/nginx-app-protect.list
RUN printf "deb [signed-by=/usr/share/keyrings/app-protect-security-updates.gpg] \
    https://pkgs.nginx.com/app-protect-security-updates/debian `lsb_release -cs` nginx-plus\n" | \
    tee /etc/apt/sources.list.d/app-protect-security-updates.list

# Download the apt configuration to `/etc/apt/apt.conf.d`:
RUN wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx

# Update the repository and install the most recent version of the NGINX App Protect WAF package (which includes NGINX Plus):
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
    apt-get update \
    && apt-get install -y app-protect


FROM nginx-installer as nginx-agent-installer

# Remove any previous NGINX Plus repository and apt configuration files:
RUN rm /etc/apt/sources.list.d/nginx-plus.list \
    rm /etc/apt/sources.list.d/*app-protect*.list \
    rm /etc/apt/apt.conf.d/90pkgs-nginx

# Add the nginx-agent repository
RUN echo "deb https://pkgs.nginx.com/nginx-agent/debian/ `lsb_release -cs` agent" \
  | sudo tee /etc/apt/sources.list.d/nginx-agent.list

# Create apt configuration /etc/apt/apt.conf.d/90pkgs-nginx
RUN echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" > /etc/apt/apt.conf.d/90pkgs-nginx \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90pkgs-nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90pkgs-nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90pkgs-nginx

# Install NGINX agent
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
    apt-get update \
    && apt-get install -y nginx-agent=$NGINX_AGENT_VERSION

FROM nginx-agent-installer as nginx-initial-config
RUN mkdir -p /nginx-initial-config
COPY nginx.conf /nginx-initial-config/
RUN cp /etc/nginx/uwsgi_params /nginx-initial-config/ \
    && cp /etc/nginx/fastcgi_params /nginx-initial-config/ \
    && cp /etc/nginx/mime.types  /nginx-initial-config/ \
    && cp /etc/nginx/scgi_params /nginx-initial-config/ \
    && chmod -R g+rw /nginx-initial-config/ \
    && chown -R :nginx-agent /nginx-initial-config/

FROM nginx-initial-config as nginx-agent-initial-config
COPY nginx-agent.conf /
RUN cat /nginx-agent.conf > /etc/nginx-agent/nginx-agent.conf \
    && rm /nginx-agent.conf \
    && usermod -a -G nginx-agent nginx \
    && usermod -a -G nginx-agent root \
    && chown -R :nginx-agent /etc/nginx-agent/nginx-agent.conf \
    && chmod -R g+rw /etc/nginx-agent/nginx-agent.conf \
    && chown -R :nginx-agent /opt \
    && chmod -R g+rw /opt \
    && chown -R :nginx-agent /var/run/nginx-agent  \
    && chmod -R g+rw /var/run/nginx-agent

FROM nginx-agent-initial-config as cleaner
# cleanup sensitive nginx-plus data
RUN apt-get autoremove --purge -y \
      gnupg \
      apt-transport-https \
  && rm -rf /root/.gnupg \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get remove --purge -y lsb-release \
  && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx-plus.list \
  && rm -rf /etc/apt/apt.conf.d/90pkgs-nginx /etc/ssl/nginx

FROM cleaner as runner
# Forward request logs to Docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/app_protect/bd-socket-plugin.log \
  && ln -sf /dev/stdout /var/log/nginx-agent/agent.log \
  && chmod -R g+rw /var/log/ \
  && chown -R :nginx-agent /var/log/

COPY entrypoint.sh /
COPY remove.sh /

# App services
EXPOSE 8000
EXPOSE 4443
# HEALTHCHECK
EXPOSE 8081
# NGINX-agent API
EXPOSE 8032
# NGINX API
EXPOSE 9000
# NGINX sync zones
EXPOSE 9001
STOPSIGNAL SIGTERM
USER nginx
ENTRYPOINT ["bash", "/entrypoint.sh"]
