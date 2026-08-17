#!/bin/sh

if [ ! -z "$K8S_TOKEN" ];then
  echo 'Found K8S_TOKEN... using K8S_TOKEN instead of TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)'
  export TOKEN=$K8S_TOKEN
else
  # Source the service account token from the container directly.
  export TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
fi

check_k8s_connectivity() {
  python3 -c "
import os, ssl, urllib.request, urllib.error

disable_tls = os.environ.get('DISABLE_TLS', 'false').lower() in ('true', '1', 'yes')
cafile = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
if disable_tls:
    ctx = ssl._create_unverified_context()
elif os.path.exists(cafile):
    ctx = ssl.create_default_context(cafile=cafile)
else:
    ctx = ssl._create_unverified_context()

url = 'https://' + os.environ['KUBERNETES_SERVICE_HOST'] + ':' + os.environ['KUBERNETES_SERVICE_PORT_HTTPS']
try:
    urllib.request.urlopen(url, timeout=5, context=ctx)
except urllib.error.HTTPError:
    # Any HTTP response (even 401/403 from an unauthenticated probe) proves
    # the API server is reachable over TLS - that's all this check needs.
    pass
"
}

if check_k8s_connectivity; then
  python3 /opt/metrics_loop/start.py https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT_HTTPS} &
  while true
  do
    pgrep -a -f -c "^python3.*metrics_loop.*$" > /dev/null || ( python3 /opt/metrics_loop/start.py https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT_HTTPS} & )
    sleep 2
  done
else
  echo "[metrics_loop] Kubernetes API server unreachable at https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT_HTTPS}, not starting metrics loop" >&2
fi
