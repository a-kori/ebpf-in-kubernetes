# 📖 Description
This repository is the code base of my Bachelor's thesis **"eBPF in Kubernetes: A Study on Routing, Security and Performance Optimization"**. It contains a CLI app allowing users to run simulations of different networking scenarios in a Minikube cluster using iPerf3: for traditional kube-proxy routing on the one hand, and for the Cilium and Calico eBPF projects on the other. In particular, it contains the following Bash scripts:
- ```main.sh```: is the entry point to the CLI app and is responsible for the communication with the user and setting up the infrastructe for the simulations. It allows you to complete or skip the installation of the necessary tools and start a Minikube cluster a the selected network option. It then sets up the metrics server and deployes the iPerf3 client (```config/iperf3-client.yaml```) and server (```config/iperf3-server.yaml```) that will generate traffic in the cluster. Finally, it allows the user to set the test parameters for a TCP/UDP test and execute it. The tests can be repeated with different parameters as often as desired.
- ```setup.sh```: installs the necessary tools for the tests and is triggered from the main file. The tools include Minikube, Docker (driver for Minikube), the kubectl CLI, iPerf3, the Calico CLI and the Cilium CLI. The last two components are not stricly necessary, but rather installed for debugging. You may also use a different driver for the Minikube cluster.
- ```test.sh```: executes the iPerf3 test with the parameters passed from the main file by running a ```kubectl exec``` command. It then measures the CPU/memory usage in the dataplane pods using ```kubectl top pods``` and parses the iPerf3 output (```results/output.txt```) for the network performance metrics. The metrics are throughput and number of retransmissions for TCP and throughput, jitter and packet loss for UDP. The passed parameters and extracted metrics are logged in ```results/tcp_test.csv``` and ```results/udp_test.csv``` tables.

In the thesis, we focus on 5 moderate-load and 5 high-load scenarios for TCP und UDP traffic each. The results of these simulations can be found in the ```results``` directory. They lay the foundation for the comparison of Cilium and Calico against the default Kubernetes networking approach. The concrete implications of the results are analyzed in the thesis.

# 💻 Running the Code
Prerequisites: 
1. The code should be run on a Linux operating system from the top directory of this repository (```ebpf-in-kubernetes```).
2. Make sure the buffer size on the sender and the receiver end is large enough for your tests. If the limit set on your machine is exceeded (e.g. by choosing a large TCP congestion window), the tests will fail. You can temporarily increase the buffer limits by running the following commands (replace 16 MB with desired value):
```
sudo sysctl -w net.core.rmem\_max=16777216 # receive buffer set to 16MB
sudo sysctl -w net.core.wmem\_max=16777216 # send buffer set to 16MB
```
To make these changes persistent, the two values must be set in the ```/etc/sysctl.conf``` file.

Now, compline and execute the main file to run the CLI app:
```
chmod +x main.sh
./main.sh
```
Have fun! 🎉
