# This dockerfile also support Ubuntu 16.04
# To use Ubuntu 16.04 replace base image with below one:
#FROM ubuntu:16.04
FROM ubuntu:18.04

LABEL maintainer="NGINX Controller Engineering"

# e.g https://<fqdn>/install/controller-agent
ARG CONTROLLER_HOST
ENV ENV_CONTROLLER_HOST=$CONTROLLER_HOST

# e.g Instance group already defined in Controller
ARG INSTANCE_GROUP
ENV ENV_CONTROLLER_INSTANCE_GROUP=$INSTANCE_GROUP

# NGXIN Plus release e.g 25
ARG NGINX_PLUS_VERSION=26

COPY nginx-plus-api.conf /etc/nginx/conf.d/
COPY entrypoint.sh /
# change lab k8s - start
COPY remove.sh /
# change lab k8s - end

# Install NGINX Plus
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
  --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  set -ex \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
  curl \
  sudo\
  vim\
  procps\
  gnupg\
  apt-utils\
  apt-transport-https\
  ca-certificates\
  distro-info-data\
  libmpdec2\
  lsb-release \
  binutils \
  net-tools \
  jq \
  && apt-get upgrade -y \
  && \
  NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
  found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
    apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
  echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" >> /etc/apt/apt.conf.d/90pkgs-nginx \
  && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90pkgs-nginx \
  && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90pkgs-nginx \
  && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90pkgs-nginx \
  && printf "deb https://pkgs.nginx.com/plus/ubuntu $(lsb_release -cs) nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
  # NGINX Javascript module needed for APIM
  && apt-get update && apt-get install -y nginx-plus=${NGINX_PLUS_VERSION}* nginx-plus-module-njs=${NGINX_PLUS_VERSION}*  \
  && rm -rf /var/lib/apt/lists/* \
  # Install ACM Agent
  && curl -k -sS -L "https://${CONTROLLER_HOST}/install/nginx-agent" > install.sh \
  && sh ./install.sh \
  # cleanup sensitive nginx-plus data
  && rm /etc/apt/sources.list.d/nginx-plus.list \
  && rm /etc/apt/apt.conf.d/90pkgs-nginx \
  && apt-key del "$NGINX_GPGKEY"

# Forward request logs to Docker log collector
RUN ln -sf /proc/1/fd/1 /var/log/nginx-controller/agent.log \
  && ln -sf /proc/1/fd/2 /var/log/nginx/error.log

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["sh", "/entrypoint.sh"]
