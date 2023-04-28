#!/bin/sh
#
# This script launches nginx and OIDC module.
#
echo "------ version 2023.04.28.01 ------"

install_path="/nginx"
agent_conf_file="/etc/nginx-agent/nginx-agent.conf"
agent_log_file="${install_path}/var/log/nginx-agent/agent.log"

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Launch nginx
echo "starting nginx ..."
${install_path}/usr/sbin/nginx -p ${install_path}/etc/nginx -c ${install_path}/etc/nginx/nginx.conf -g "daemon off; load_module modules/ngx_http_js_module.so;" &

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
echo "updating ${agent_conf_file} ..."

if [ ! -f "${agent_conf_file}" ]; then
  test -f "${agent_conf_file}.default" && \
  cp -p "${agent_conf_file}.default" "${agent_conf_file}" || \
  { echo "no ${agent_conf_file}.default found! exiting."; exit 1; }
fi

test -n "${ENV_CONTROLLER_HOST}" && \
echo " ---> using controller api url = ${ENV_CONTROLLER_HOST}" && \
sh -c "sed -i.old -e 's@^\s\shost:\s.*@  host: ${ENV_CONTROLLER_HOST}@' \
${agent_conf_file}"

test -f "${agent_conf_file}" && \
chmod 644 ${agent_conf_file} && \
chown nginx ${agent_conf_file} > /dev/null 2>&1

echo "starting nginx-agent with instance group ${ENV_CONTROLLER_INSTANCE_GROUP} and host ${ENV_CONTROLLER_HOST} ..."
/usr/bin/nginx-agent \
  --instance-group ${ENV_CONTROLLER_INSTANCE_GROUP} \
  --server-host ${ENV_CONTROLLER_HOST} \
  --server-grpcport 443 \
  --tls-enable \
  --tls-skip-verify \
  --log-level info \
  --log-path ${install_path}/var/log/nginx-agent/ \
  --nginx-exclude-logs "" \
  --nginx-socket "unix:/var/run/nginx-agent/nginx.sock" \
  --dataplane-status-poll-interval 30s \
  --dataplane-report-interval 24h \
  --metrics-bulk-size 20 \
  --metrics-report-interval 1m \
  --metrics-collection-interval 15s \
  --metrics-mode aggregated \
  --config-dirs "${install_path}/etc/nginx:/usr/local/etc/nginx:/usr/share/nginx/modules:/etc/nms" \
  --advanced-metrics-socket-path /var/run/nginx-agent/advanced-metrics.sock \
  --advanced-metrics-aggregation-period 1s \
  --advanced-metrics-publishing-period 3s \
  --advanced-metrics-table-sizes-limits-staging-table-max-size 1000 \
  --advanced-metrics-table-sizes-limits-staging-table-threshold 1000 \
  --advanced-metrics-table-sizes-limits-priority-table-max-size 1000 \
  --advanced-metrics-table-sizes-limits-priority-table-threshold 1000 \
  &

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

echo "nginx process has stopped, exiting."
