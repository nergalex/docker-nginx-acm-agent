#!/bin/sh
#
# This script launches nginx and nginx-agent
#
echo "------ version 2023.05.04.02 ------"

install_path="/nginx"
nginx_config_path="/nginx-config"

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Copy initial nginx config to empty volume
cp ${install_path}/etc/nginx/nginx.conf ${nginx_config_path}/nginx.conf

# Launch nginx
echo "starting nginx ..."
${install_path}/usr/sbin/nginx -p ${install_path}/etc/nginx -c ${nginx_config_path}/nginx.conf -g "daemon off; load_module modules/ngx_http_js_module.so;" &

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
/usr/bin/nginx-agent &

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check nginx-agent logs"
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
    echo "UNREGISTER instance from NMS"
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
