#!/bin/sh
#
# This script launches nginx and the NGINX Controller Agent.
#
echo "------ version 2022.12.30.01 ------"

# Variables
agent_conf_file="/etc/nginx-agent/nginx-agent.conf"
agent_log_file="/var/log/nginx-agent/agent.log"
controller_host=""

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx-agent ..."
    kill -TERM "${agent_pid}" 2>/dev/null
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Launch NAP
echo "starting nginx app protect ..."
/bin/su -s /bin/sh -c "/usr/share/ts/bin/bd-socket-plugin tmm_count 4 proc_cpuinfo_cpu_mhz 2000000 total_xml_memory 307200000 total_umu_max_size 3129344 sys_max_account_id 1024 no_static_config 2>&1 >> /var/log/app_protect/bd-socket-plugin.log &" nginx
bd_socket_pid=$(pgrep bd-socket)

# Launch nginx
echo "starting nginx ..."
/usr/sbin/nginx -g "daemon off;" &
nginx_pid=$!

wait_workers()
{
    while ! pgrep -f 'nginx: worker process' >/dev/null 2>&1; do
        echo "waiting for nginx workers ..."
        sleep 2
    done
}

wait_workers

# Launch nginx-agent
test -n "${ENV_CONTROLLER_HOST}" && \
    controller_host=${ENV_CONTROLLER_HOST}

test -n "${ENV_CONTROLLER_INSTANCE_GROUP}" && \
    instance_group=${ENV_CONTROLLER_INSTANCE_GROUP}

if [ -n "${controller_host}" ]; then
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

if [ -n "${instance_group}" ]; then
  echo "starting nginx-agent with instance group ${instance_group}..."
  /usr/bin/nginx-agent \
  --instance-group ${instance_group} \
  --config-dirs "/etc/nginx:/usr/local/etc/nginx:/usr/share/nginx/modules:/etc/nms:/etc/app_protect" &
  # > /dev/null 2>&1 < /dev/null &
else
  echo "starting nginx-agent..."
  /usr/bin/nginx-agent > /dev/null 2>&1 < /dev/null &
fi

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check ${agent_log_file}"
    exit 1
fi

wait_term()
{
    wait ${agent_pid}
    trap '' EXIT INT TERM
    kill -QUIT "${nginx_pid}" 2>/dev/null
    echo "waiting for nginx to stop..."
    wait ${nginx_pid}
    kill -TERM "${agent_pid}" 2>/dev/null
    echo "terminating nginx-agent..."
    # unregister - start
    echo "UNREGISTER instance from ACM"
    export ENV_CONTROLLER_USER=${ENV_CONTROLLER_USER}
    export ENV_CONTROLLER_PASSWORD=${ENV_CONTROLLER_PASSWORD}
    export ENV_CONTROLLER_HOST=${ENV_CONTROLLER_HOST}
    export ENV_CONTROLLER_INSTANCE_GROUP=${ENV_CONTROLLER_INSTANCE_GROUP}
    sleep 60
    sh remove.sh
    echo "UNREGISTER done"
    # unregister - end
}

wait_term

echo "nginx-agent process has stopped, exiting."


