FROM debian:bullseye-slim as nginx-installer

LABEL maintainer="F5 SE"

# Define NGINX versions for NGINX Plus and NGINX Plus modules
ARG NGINX_PLUS_VERSION=28
ARG NGINX_PLUS_VERSION_MINOR=1
ARG NJS_VERSION="0.7.10"
ARG INSTALL_PATH="/nginx"
ARG TMP_PATH="/nginx-tmp"
ARG CACHE_PATH="/nginx-cache"

# Download certificate and key from the customer portal (https://account.f5.com)
# and copy to the build context
RUN --mount=type=secret,id=nginx-crt,dst=nginx-repo.crt \
    --mount=type=secret,id=nginx-key,dst=nginx-repo.key \
    set -x \
    \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system nginx || true \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false nginx || true \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        ca-certificates \
                        gnupg1 \
                        lsb-release \
                        curl  \
                        sudo\
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
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
        hkp://keyserver.ubuntu.com:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    \
# Install the latest release of NGINX Plus and/or NGINX Plus modules
    && echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" > /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90nginx \
    && printf "deb https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
    && mkdir -p /etc/ssl/nginx \
    && cat nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt \
    && cat nginx-repo.key > /etc/ssl/nginx/nginx-repo.key \
    && apt-get update \
    \
# Temporary directory to store installation files
    && tempDir="$(mktemp -d)" \
    && chmod 777 "${tempDir}" \
    && cd ${tempDir} \
    && wget https://raw.githubusercontent.com/nginxinc/nginx-plus-install-tools/main/ngxunprivinst.sh \
    && chmod +x ngxunprivinst.sh \
    \
# Download nginx-plus-module-metrics package on NMS repo \
    && repoNmsUrl=https://pkgs.nginx.com/nms/debian/pool/nginx-plus/n/nginx-plus-module-metrics/ \
    && moduleName=`wget --certificate=/etc/ssl/nginx/nginx-repo.crt --private-key=/etc/ssl/nginx/nginx-repo.key $repoNmsUrl -O- | fgrep 'nginx-plus-module' | fgrep deb | fgrep -v dbg | cut -d '"' -f2 | fgrep bullseye | fgrep amd64 | fgrep "_$NGINX_PLUS_VERSION"` \
    && wget --certificate=/etc/ssl/nginx/nginx-repo.crt --private-key=/etc/ssl/nginx/nginx-repo.key ${repoNmsUrl}${moduleName} \
    && mv nginx-plus-module-metrics_${NGINX_PLUS_VERSION}* nginx-plus-module-metrics.rpm \
    \
# Download and Install packages
    && ./ngxunprivinst.sh fetch -c /etc/ssl/nginx/nginx-repo.crt -k /etc/ssl/nginx/nginx-repo.key -v ${NGINX_PLUS_VERSION}-${NGINX_PLUS_VERSION_MINOR} \
    && mv nginx-plus_${NGINX_PLUS_VERSION}* nginx-plus.rpm \
    && mv nginx-plus-module-brotli_${NGINX_PLUS_VERSION}* nginx-plus-module-brotli.rpm \
    && mv nginx-plus-module-njs_${NGINX_PLUS_VERSION}%2B${NJS_VERSION}-* nginx-plus-module-njs.rpm \
    && mv nginx-plus-module-subs-filter_${NGINX_PLUS_VERSION}* nginx-plus-module-subs-filter.rpm \
    && mkdir -p $INSTALL_PATH \
    && ./ngxunprivinst.sh install -y -p $INSTALL_PATH nginx-plus.rpm nginx-plus-module-brotli.rpm nginx-plus-module-njs.rpm nginx-plus-module-subs-filter.rpm nginx-plus-module-metrics.rpm \
    && chown -R nginx:nginx $INSTALL_PATH \
    && chmod -R g+w $INSTALL_PATH/etc/nginx \
    && sudo mkdir /var/log/nginx \
    && sudo touch /var/log/nginx/error.log \
    && sudo chown -R nginx:nginx /var/log/nginx

FROM nginx-installer as agent-installer

# Install GO
RUN wget https://go.dev/dl/go1.20.3.linux-amd64.tar.gz \
    && rm -rf /usr/local/go && tar -C /usr/local -xzf go1.20.3.linux-amd64.tar.gz \
    && export PATH=$PATH:/usr/local/go/bin \
    && go version

# Install NGINX agent
RUN wget https://github.com/nginx/agent/releases/download/v2.25.1/nginx-agent-2.25.1.bullseye_amd64.deb \
    && sudo dpkg -i nginx-agent-2.25.1.bullseye_amd64.deb

FROM agent-installer as nginx-config-update
# implement changes required to run NGINX as an unprivileged user
RUN sed -i "s,listen       80;,listen       8080;," ${INSTALL_PATH}/etc/nginx/conf.d/default.conf \
    && sed -i "/user  nginx;/d" ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "s,.*/var/run/nginx.pid;,pid ${TMP_PATH}/nginx.pid;," ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "s,proxy_temp_path.*,proxy_temp_path ${CACHE_PATH}/proxy_temp;," ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "s,client_body_temp_path.*,client_body_temp_path ${CACHE_PATH}/client_temp;," ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "s,fastcgi_temp_path.*,fastcgi_temp_path ${CACHE_PATH}/fastcgi_temp;," ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "s,uwsgi_temp_path.*,uwsgi_temp_path ${CACHE_PATH}/uwsgi_temp;," ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "s,scgi_temp_path.*,scgi_temp_path ${CACHE_PATH}/scgi_temp;," ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && mkdir ${INSTALL_PATH}/var/log/nginx-agent/ \
    && touch ${INSTALL_PATH}/var/log/nginx-agent/agent.log \
    && chown -R nginx:nginx ${INSTALL_PATH}/var/log/nginx-agent \
    && chmod -R go+rw ${INSTALL_PATH}/var/log/nginx-agent \
    && chown -R nginx:nginx ${INSTALL_PATH}/var/log/nginx \
    && chmod -R go+rw ${INSTALL_PATH}/var/log/nginx \
    && chown -R nginx:nginx /etc/nginx-agent/ \
    && chmod -R go+w /etc/nginx-agent/ \
    && chown -R nginx:nginx /var/run/nginx-agent \
    && chmod -R go+w /var/run/nginx-agent \
    && ln -s  ${INSTALL_PATH}/etc/nginx /etc/nginx \
    && chown nginx:nginx /etc/nginx \
    && ln -s  ${INSTALL_PATH}/usr/lib/nginx /usr/lib/nginx \
    && chown nginx:nginx /usr/lib/nginx

FROM nginx-config-update as cleaner
# cleanup sensitive nginx-plus data
RUN apt-get autoremove --purge -y \
      gnupg \
      apt-transport-https \
  && rm -rf /root/.gnupg \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf "${tempDir}" \
  && apt-get remove --purge -y lsb-release \
  && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx-plus.list \
  && rm -rf /etc/apt/apt.conf.d/90nginx /etc/ssl/nginx

FROM cleaner as runner
# Forward request logs to Docker log collector
RUN ln -sf /dev/stdout ${INSTALL_PATH}/var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && ln -sf /dev/stderr ${INSTALL_PATH}/var/log/nginx/error.log \
  && ln -sf /dev/stdout ${INSTALL_PATH}/var/log/nginx-agent/agent.log

COPY entrypoint.sh /
COPY remove.sh /

EXPOSE 8080
EXPOSE 4443
STOPSIGNAL SIGTERM
USER nginx
ENTRYPOINT ["bash", "/entrypoint.sh"]
