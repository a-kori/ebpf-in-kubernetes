#!/bin/bash
echo "👋 Welcome to the network performance test!"

# Install necessary tools, if needed
echo "🔧 Are the necessary tools set up? (y for yes)"
read tools
if [[ ! " y yes " =~ " $tools " ]]; then
    chmod +x setup.sh
    ./setup.sh
fi

# Main loop
while true
do
    echo "🔌 Choose the network option to test (kube-proxy, cilium, calico): "
    read opt
    case $opt in
        "kube-proxy")
            echo "🚀 Starting the cluster with standard kube-proxy routing..."
            minikube start
            ;;
        "cilium")
            echo "🚀 Starting the cluster with the Cilium CNI..."
            minikube start --cni=cilium
            ;;
        "calico")
            echo "🚀 Starting the cluster with the Calico CNI..."
            minikube start --cni=calico
            # Make sure to enable eBPF dataplane, since iptables are default
            kubectl set env daemonset calico-node -n kube-system FELIX_BPFENABLED=true
            ;;
        *)
            echo "Invalid input."
            continue
            ;;
    esac
    echo "Waiting a minute for the changes to apply..."
    sleep 60

    # Add the metrics server
    echo "🚀 Setting up the metrics server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Ignore TLS verification for metrics server
    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

    # Apply iPerf3 configuration
    echo "Deploying iPerf3 server and client..."
    kubectl apply -f iperf3-server.yaml
    kubectl apply -f iperf3-client.yaml
    sleep 20

    while true
    do
        echo "🧪 Choose the parameters for the network performance test. Click Enter to use the default value."
        echo "Choose the network protocol (tcp or udp, tcp default): "
        read protocol
        if [ -z "$protocol" ]; then
            protocol="tcp"
        fi
        echo "Choose the test duration in seconds, -t: "
        read duration
        if [ -z "$duration" ]; then
            duration="10"
        fi
        echo "Choose the number of parallel streams, -P: "
        read streams
        if [ -z "$streams" ]; then
            streams="1"
        fi

        if [ "$protocol" == "udp" ]; then
            echo "Choose the bandwidth (format 10M, 1G etc.), -b: "
            read bandwidth
            echo "Choose the packet size in bytes, -l: "
            read size
        else
            echo "Choose the congestion window size (up to 416K), -w: "
            read cwnd
        fi
        if [ -z "$bandwidth" ]; then
            bandwidth="1M"
        fi
        if [ -z "$size" ]; then
            size="1470"
        fi
        if [ -z "$cwnd" ]; then
            cwnd="unset"
        fi

        chmod +x test.sh
        ./test.sh "$opt" "$protocol" "$duration" "$streams" "$bandwidth" "$size" "$cwnd"

        echo "Do you want to try $opt with different parameters? (y for yes)"
        read repeat
        if [[ ! " y yes " =~ " $repeat " ]]; then
            minikube delete
            break
        fi
    done

    echo "Do you want to try a different network option? (y for yes)"
    read repeat
    if [[ ! " y yes " =~ " $repeat " ]]; then
        echo "👋 Shutting down, bye-bye!"
        break
    fi
done
