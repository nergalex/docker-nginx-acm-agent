#ARG STORE_UUID=False
FROM centos:7 as nginx-installer

LABEL maintainer="NGINX Controller Engineering"

# NGXIN Plus release e.g 26
ARG NGINX_PLUS_VERSION=26

COPY nginx-plus-api.conf /etc/nginx/conf.d/
COPY entrypoint.sh /
# change lab k8s - start
COPY remove.sh /
# change lab k8s - end

ENV NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

# Install NGINX Plus
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
  --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  set -ex \
  && yum -y update && yum -y upgrade \
  && yum -y install epel-release \
  && yum -y install wget ca-certificates epel-release curl sudo vim procps gnupg binutils net-tools \
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

FROM nginx-installer as agent-installer
# Install Controller Agent
ARG CONTROLLER_HOST
ARG CONTROLLER_IP
#ARG API_KEY
#ENV ENV_CONTROLLER_API_KEY=$API_KEY
#ARG STORE_UUID
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  echo "${CONTROLLER_IP}    ${CONTROLLER_HOST}" >> /etc/hosts \
  && curl -k -sS -L "https://${CONTROLLER_HOST}/install/nginx-agent" --resolve "${CONTROLLER_HOST}:443:${CONTROLLER_IP}" > install.sh \
  && sh ./install.sh

FROM agent-installer as cleaner
# cleanup sensitive nginx-plus data
RUN gpg --list-keys
RUN rm /etc/yum.repos.d/nginx-plus-7.4.repo \
  && gpg --batch --delete-keys $NGINX_GPGKEY \
  && sed -i '$d' /etc/hosts

FROM cleaner as runner
## e.g '1234567890'
#ARG API_KEY
#ENV ENV_CONTROLLER_API_KEY=$API_KEY

# e.g https://<fqdn>/install/controller-agent
ARG CONTROLLER_HOST
ENV ENV_CONTROLLER_HOST=$CONTROLLER_HOST

# e.g True or False
#ARG STORE_UUID
#ENV ENV_CONTROLLER_STORE_UUID=$STORE_UUID

# e.g Instance location already defined in Controller
#ARG LOCATION
#ENV ENV_CONTROLLER_LOCATION=$LOCATION

# e.g Instance group already defined in Controller
ARG INSTANCE_GROUP
ENV ENV_CONTROLLER_INSTANCE_GROUP=$INSTANCE_GROUP

# Forward request logs to Docker log collector
RUN ln -sf /proc/1/fd/1 /var/log/nginx-agent/agent.log \
  && ln -sf /proc/1/fd/2 /var/log/nginx/error.log

COPY custom_log_format.json /etc/nginx/

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["sh", "/entrypoint.sh"]
