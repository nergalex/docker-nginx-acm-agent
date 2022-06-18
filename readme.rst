NGINX API Connectivity Manager agent - K8S deployment
##############################################################

Build
=========================================

.. code-block:: bash

    DOCKER_BUILDKIT=1 \
      docker build \
      --add-host=nginx-acm:10.0.0.4 \
      --build-arg CONTROLLER_HOST=nginx-acm \
      --build-arg INSTANCE_GROUP=sentence-non-prod \
      --tag nginx-agent:aks \
      --secret id=nginx-crt,src=nginx-repo.crt \
      --secret id=nginx-key,src=nginx-repo.key \
      .

Deploy
=========================================

.. code-block:: bash

    kubectl apply -f ./manifest.yaml




