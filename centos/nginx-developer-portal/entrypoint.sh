#!/bin/bash
#
# This script launches nginx, nginx devportal and nginx agent.
#
echo "------ version 2022.10.04.01 ------"

# Variables
agent_conf_file="/etc/nginx-agent/nginx-agent.conf"
agent_log_file="/var/log/nginx-agent/agent.log"
devportal_conf_file="/etc/nginx-devportal/devportal.conf"
devportal_log_file="/var/log/nginx-devportal.log"

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx-agent ..."
    kill -TERM "${agent_pid}" 2>/dev/null
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Launch nginx
echo "starting nginx ..."
nginx -g "daemon off;" &
nginx_pid=$!

wait_workers()
{
    while ! pgrep -f 'nginx: worker process' >/dev/null 2>&1; do
        echo "waiting for nginx workers ..."
        sleep 2
    done
}

wait_workers

# Configure nginx-devportal
test -n "${ENV_DB_NAME}" && \
    db_name=${ENV_DB_NAME}
test -n "${ENV_DB_HOST}" && \
    db_host=${ENV_DB_HOST}
test -n "${ENV_DB_PORT}" && \
    db_port=${ENV_DB_PORT}
test -n "${ENV_DB_USER}" && \
    db_user=${ENV_DB_USER}
test -n "${ENV_DB_PASSWORD}" && \
    db_password=${ENV_DB_PASSWORD}

if [ -n "${db_name}" -o -n "${db_host}" -o -n "${db_port}" -o -n "${db_user}" -o -n "${db_password}" ]; then
    echo "updating ${devportal_conf_file} ..."

    # db_name
    test -n "${db_name}" && \
    echo " ---> using db_name = ${db_name}" && \
    sh -c "sed -i.old -e 's@^\#\sDB_NAME=.*@DB_NAME=\"${db_name}\"@' \
	${devportal_conf_file}"

    # db_host
    test -n "${db_host}" && \
    echo " ---> using db_host = ${db_host}" && \
    sh -c "sed -i.old -e 's@^\#\sDB_HOST=.*@DB_HOST=\"${db_host}\"@' \
	${devportal_conf_file}"

    # db_port
    test -n "${db_port}" && \
    echo " ---> using db_port = ${db_port}" && \
    sh -c "sed -i.old -e 's@^\#\sDB_PORT=.*@DB_PORT=\"${db_port}\"@' \
	${devportal_conf_file}"

    # db_user
    # Azure PaaS DB: the Username should be in <username@hostname> format.
    db_email=( $(echo ${db_user} | tr "@" "\n") )
    db_email_user=${db_email[0]}
    db_email_host=${db_email[1]}
    test -n "${db_email_user}" && \
    test -n "${db_email_host}" && \
    echo " ---> using db_user = ${db_user}" && \
    sh -c "sed -i.old -e 's@^\#\sDB_USER=.*@DB_USER=\"${db_email_user}\@${db_email_host}\"@' \
	${devportal_conf_file}"

    # db_password
    test -n "${db_password}" && \
    echo " ---> using db_password = ${db_password}" && \
    sh -c "sed -i.old -e 's@^\#\sDB_PASSWORD=.*@DB_PASSWORD=\"${db_password}\"@' \
	${devportal_conf_file}"

    # db_type
    echo " ---> using db_type = psql" && \
    sh -c "sed -i.old -e 's@^DB_TYPE=.*@DB_TYPE=\"psql\"@' \
	${devportal_conf_file}"
fi

# Launch nginx-devportal
echo "starting nginx-devportal ..."
/usr/bin/nginx-devportal server > /dev/null 2>&1 < /dev/null &

devportal_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the devportal, please check ${devportal_log_file}"
    exit 1
fi

# Launch nginx-agent
test -n "${ENV_CONTROLLER_HOST}" && \
    controller_host=${ENV_CONTROLLER_HOST}

test -n "${ENV_CONTROLLER_INSTANCE_GROUP}" && \
    instance_group=${ENV_CONTROLLER_INSTANCE_GROUP}

if [ -n "${controller_host}" -o -n "${instance_group}" ]; then
    echo "updating ${agent_conf_file} ..."

    if [ ! -f "${agent_conf_file}" ]; then
      test -f "${agent_conf_file}.default" && \
      cp -p "${agent_conf_file}.default" "${agent_conf_file}" || \
      { echo "no ${agent_conf_file}.default found! exiting."; exit 1; }
    fi

    test -n "${controller_host}" && \
    echo " ---> using controller api url = ${controller_host}" && \
    sh -c "sed -i.old -e 's@^\s\shost:\s.*@  host: $controller_host@' \
	${agent_conf_file}"

    test -f "${agent_conf_file}" && \
    chmod 644 ${agent_conf_file} && \
    chown nginx ${agent_conf_file} > /dev/null 2>&1
fi

echo "starting nginx-agent ..."
/usr/bin/nginx-agent > /dev/null 2>&1 < /dev/null &

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check ${agent_log_file}"
    exit 1
fi

wait_term()
{
    wait ${agent_pid}
    trap - TERM
    kill -QUIT "${nginx_pid}" 2>/dev/null
    echo "waiting for nginx to stop..."
    wait ${nginx_pid}
    # unregister - start
    export ENV_CONTROLLER_USER=${ENV_CONTROLLER_USER}
    export ENV_CONTROLLER_PASSWORD=${ENV_CONTROLLER_PASSWORD}
    export ENV_CONTROLLER_HOST=${ENV_CONTROLLER_HOST}
    export ENV_CONTROLLER_INSTANCE_GROUP=${ENV_CONTROLLER_INSTANCE_GROUP}
    echo "waiting for NGINX Instance Manager (NIM) to be seen as Offline..."
    sleep 45
    echo "starting UNREGISTER instance from NIM..."
    sh remove.sh
    echo "UNREGISTER done"
    # unregister - end
}

wait_term

echo "acm-agent process has stopped, exiting."


