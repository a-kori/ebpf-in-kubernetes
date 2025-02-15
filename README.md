# Introduction
This repository is the code base of my Bachelor's thesis "eBPF in Kubernetes: A Study on Routing, Security and Performance Optimization". It contains simulations of different networking and security scenarios in a default Kubernetes environment as well as with four eBPF-based projects: Cilium, Calico, Tetragon and Falco. The results of these simulations lay the foundation for the comparison of the four tools against the default Kubernetes solution, which is further analyzed in the thesis.

# Initial Setup
To be able to run the simulations, you need to set up a Kubernetes cluster and install the necessary tools. You may use [this guide](https://gaganmanku96.medium.com/kubernetes-setup-with-minikube-on-wsl2-2023-a58aea81e6a3) to setup a Minikube cluster on WSL2.
