#!/bin/sh
#
# This script launches nginx and nginx-agent
#
echo "------ version 2025.07.02.3 ------"

# copy initial file to the empy volume, in case of being empty
cp -p --no-clobber /nginx-initial-config/* /etc/nginx/

handle_term()
{
    echo "$(date +%H:%M:%S:%N): received TERM signal"
    # stopping nginx ...
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Launch nginx app protect WAF
echo "starting nginx app protect waf ..."
/usr/share/ts/bin/bd-socket-plugin tmm_count 4 proc_cpuinfo_cpu_mhz 2000000 total_xml_memory 307200000 total_umu_max_size 3129344 sys_max_account_id 1024 no_static_config 2>&1 >> /var/log/app_protect/bd-socket-plugin.log &

# Launch nginx
echo "starting nginx ..."
/usr/sbin/nginx -p /etc/nginx -c /etc/nginx/nginx.conf -g "daemon off;" &

nginx_pid=$!

wait_workers()
{
    while ! pgrep -f 'nginx: worker process' >/dev/null 2>&1; do
        echo "waiting for nginx workers ..."
        sleep 2
    done
}

wait_workers

# Allow write access to nginx-agent
chown :nginx-agent /nginx-tmp/nginx.pid
chmod -R g+rw /nginx-tmp/nginx.pid

# Launch nginx-agent
/usr/bin/nginx-agent &
echo "nginx-agent started"

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check nginx-agent logs"
    exit 1
fi

wait_term()
{
    wait ${nginx_pid}
    trap '' EXIT INT TERM
    echo "$(date +%H:%M:%S:%N): nginx stopped"
    # stopping nginx-agent ...
    kill -QUIT "${agent_pid}" 2>/dev/null
    echo "$(date +%H:%M:%S:%N): nginx-agent stopped..."
    # unregister - start
#    echo "UNREGISTER instance from NMS"
#    export ENV_CONTROLLER_USER=${ENV_CONTROLLER_USER}
#    export ENV_CONTROLLER_PASSWORD=${ENV_CONTROLLER_PASSWORD}
#    export ENV_CONTROLLER_HOST=${ENV_CONTROLLER_HOST}
#    export ENV_CONTROLLER_INSTANCE_GROUP=${ENV_CONTROLLER_INSTANCE_GROUP}
#    sleep 60
#    sh remove.sh
#    echo "UNREGISTER done"
    # unregister - end
}

wait_term
echo "$(date +%H:%M:%S:%N):exiting."