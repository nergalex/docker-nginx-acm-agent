#ARG STORE_UUID=False
FROM centos:7 as nginx-installer

LABEL maintainer="F5 SE"

# NGXIN Plus release
ARG NGINX_PLUS_VERSION=27

COPY entrypoint.sh /
COPY remove.sh /

ENV NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

# Install NGINX Plus
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
  --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  set -ex \
  && yum -y update && yum -y upgrade \
  && yum -y install epel-release \
  && yum -y install wget ca-certificates epel-release curl sudo vim procps gnupg binutils net-tools jq tcpdump \
  && \
  found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
    gpg --keyserver "$server" --recv-keys "0x$NGINX_GPGKEY" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
  wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nginx-plus-7.4.repo \
  # NGINX Javascript module needed for APIM
  && yum update && yum -y install nginx-plus-${NGINX_PLUS_VERSION}* nginx-plus-module-njs-${NGINX_PLUS_VERSION}*

# Add NGINX App-protect repo to Yum
RUN wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/app-protect-7.repo

# Install NGINX App Protect WAF
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
    yum -y install app-protect app-protect-attack-signatures app-protect-threat-campaigns
COPY custom_log_format.json /etc/nginx/

FROM nginx-installer as agent-installer
# Install Controller Agent
ARG CONTROLLER_HOST
ARG CONTROLLER_IP
ARG INSTANCE_GROUP

# Install NGINX agent
RUN curl -k -sS -L "https://${CONTROLLER_HOST}/install/nginx-agent" > install.sh \
  && sh ./install.sh --instance-group ${INSTANCE_GROUP}

# Install NGINX Plus Metrics Module
COPY nginx-agent_advanced_metrics.conf /
RUN --mount=type=secret,id=nms-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
  --mount=type=secret,id=nms-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nms.repo \
  && curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key \
  && rpmkeys --import /tmp/nginx_signing.key \
  && yum install -y nginx-plus-module-metrics \
  && cat nginx-agent_advanced_metrics.conf >> /etc/nginx-agent/nginx-agent.conf \
  && rm nginx-agent_advanced_metrics.conf

FROM agent-installer as cleaner
# cleanup sensitive nginx-plus data
RUN gpg --list-keys
RUN rm /etc/yum.repos.d/nginx-plus-7.4.repo \
  && gpg --batch --delete-keys $NGINX_GPGKEY \
  && yum clean all \
  && rm -rf /var/cache/yum

FROM cleaner as runner

# Forward request logs to Docker log collector
RUN ln -sf /proc/1/fd/1 /var/log/nginx-agent/agent.log \
  && ln -sf /proc/1/fd/2 /var/log/nginx/error.log

EXPOSE 80
EXPOSE 443

STOPSIGNAL SIGTERM

ENTRYPOINT ["sh", "/entrypoint.sh"]
