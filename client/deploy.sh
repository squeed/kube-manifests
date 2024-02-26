#!/bin/bash -e

shopt -s expand_aliases

alias k=kubectl
alias kass="kubectl apply --server-side"

APISERVER="$(k get node -l node-role.kubernetes.io/control-plane= -o jsonpath='{.items[*].status.addresses[0].address}')"
OTHER_NODE="$(k get node -l 'node-role.kubernetes.io/control-plane!=' -o jsonpath='{.items[0].status.addresses[0].address}')"
APISERVICE="$(k -n default get service kubernetes -o jsonpath='{.spec.clusterIP}')"



echo "targets: APISERVER: $APISERVER OTHER_NODE: $OTHER_NODE"

function ns() {
    local name="$1"
    if ! k get namespace "$name" > /dev/null; then
        k create namespace "$name"
    fi
}

function onAllPods() {
    local ns="$1"
    local cmd="$2"
    
    local failed=0

    for pod in $(k -n "$ns" get pods -o jsonpath='{.items[*].metadata.name}'); do
        date
        echo k exec -n "$ns" "$pod" -- $cmd
        if k exec -n "$ns" "$pod" -- $cmd; then
            a=1;
        else
            failed=1;
        fi
        echo;
    done
    if [ $failed -gt 0 ]; then
        echo test case failed
        exit 1
    fi
    echo
}

function deploy() {
    ns foo-eks
    ns foo-api
    ns foo-remote-node


    kass -n foo-eks -f client-daemonset.yaml
    kass -n foo-api -f client-daemonset.yaml
    kass -n foo-remote-node -f client-daemonset.yaml

    sed "s/APISERVER/$APISERVER/" knp-client-allow-apiserver.yaml | kass -n foo-eks -f -
    kass -n foo-api -f cnp-apiserver.yaml
    kass -n foo-remote-node -f cnp-remote-node.yaml
}

function test_eks() {
    # add checks here
    echo "eks pod -> apiserver (should pass)"
    onAllPods foo-eks "curl --connect-timeout 3 -k -s https://$APISERVER:6443/healthz"

    #echo "eks pod -> kubelet (should fail)"
    #onAllPods foo-eks "curl --connect-timeout 3 -k -s http://$OTHER_NODE:10256/healthz"
}

function test_api() {
    echo "apiserver case"
    onAllPods foo-api "curl --connect-timeout 3 -k -s https://$APISERVICE/healthz"
}

function test_remote() {
    echo "remote-node case"
    onAllPods foo-remote-node "curl -k -s http://$OTHER_NODE:10256/healthz"
}

deploy

test_eks
test_api
test_remote
