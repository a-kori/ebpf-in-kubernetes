#!/bin/bash
OUTPUT_FILE="results/output.txt"

# parse_tcp parses the iPerf3 test output for TCP traffic
# and extracts the bitrate and retransmissions metrics
parse_tcp () {
    # Check if the iPerf3 output file exists
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        echo "Error: File '$OUTPUT_FILE' not found!"
        return
    fi

    # Extract the last "sender" line (ignoring other lines)
    SENDER_LINE=$(grep 'sender' "$OUTPUT_FILE" | tail -n 1)

    # Parse Bitrate and Retr from the sender line
    BITRATE=$(echo "$SENDER_LINE" | awk '{print $(NF-3), $(NF-2)}')
    RETRANSMITS=$(echo "$SENDER_LINE" | awk '{print $(NF-1)}')
}

# parse_udp parses the iPerf3 test output for UDP traffic
# and extracts the throughput, jitter and packet loss metrics
parse_udp () {
    # Check if the iPerf3 output file exists
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        echo "Error: File '$OUTPUT_FILE' not found!"
        return
    fi

    # Extract the last "receiver" line (for UDP results; use sender as fallback)
    RECEIVER_LINE=$(grep 'receiver' "$OUTPUT_FILE" | tail -n 1)

    # If no receiver line exists, fallback to sender line
    if [[ -z "$RECEIVER_LINE" ]]; then
        RECEIVER_LINE=$(grep 'sender' "$OUTPUT_FILE" | tail -n 1)
    fi

    # Parse throughput, jitter, and packet loss from the receiver/sender line
    THROUGHPUT=$(echo "$RECEIVER_LINE" | awk '{print $(NF-6), $(NF-5)}')
    JITTER=$(echo "$RECEIVER_LINE" | awk '{print $(NF-4)}')
    PACKET_LOSS_RAW=$(echo "$RECEIVER_LINE" | grep -oP '\d+/\d+') # Extracts lost/total datagrams (e.g., 0/906)
    PACKET_LOSS_PERCENT=$(echo "$RECEIVER_LINE" | grep -oP '\(\K[^)]+' || echo "0") # Extracts percentage (e.g., 0%)
}

# Set arguments
OPT=$1
PROTOCOL=$2
DURATION=$3
STREAMS=$4
BANDWIDTH=$5
SIZE=$6
CWND=$7

if [ "$PROTOCOL" == "udp" ]; then
    # Run iperf3 command
    echo "Running iPerf3 test for $OPT ($PROTOCOL, $DURATION seconds, $STREAMS streams, ${BANDWIDTH}bps bandwidth, $SIZE bytes packet size)..."
    kubectl exec iperf3-client -- iperf3 -c iperf3-service -u -t $DURATION -P $STREAMS -b $BANDWIDTH -l $SIZE > $OUTPUT_FILE

    # Measure CPU/memory utilization on dataplane pod
    SEARCH="$OPT"
    if [ "$OPT" == "calico" ]; then
        SEARCH="$OPT-node"
    fi
    CPU_USAGE=$(kubectl top pods -n kube-system | grep $SEARCH | awk '{print $2}' | head -n 1)
    MEM_USAGE=$(kubectl top pods -n kube-system | grep $SEARCH | awk '{print $3}' | head -n 1)
    
    # Parse throughput, jitter and packet loss
    parse_udp

    # Log result into a CSV file
    LOG_FILE="results/udp_test.csv"
    if [ ! -f "$LOG_FILE" ]; then
        echo "Network,Protocol,Duration (in seconds),Streams,Bandwidth,Packet Size,Throughput,Jitter,Packet Loss,CPU,Memory,DateTime" > "$LOG_FILE"
    fi
    echo "$OPT,$PROTOCOL,$DURATION,$STREAMS,$BANDWIDTH,$SIZE,$THROUGHPUT,$JITTER,$PACKET_LOSS_RAW ($PACKET_LOSS_PERCENT),$CPU_USAGE,$MEM_USAGE,$(date +%Y-%m-%d_%H:%M:%S)" >> "$LOG_FILE"
else
    # Run iperf3 command
    PARAM=""
    if [ "$CWND" != "unset" ]; then
        PARAM="-w $CWND"
    fi
    echo "Running iPerf3 test for $OPT ($PROTOCOL, $DURATION seconds, $STREAMS streams, $CWND congestion window)..."
    kubectl exec iperf3-client -- iperf3 -c iperf3-service -t $DURATION -P $STREAMS $PARAM > $OUTPUT_FILE

    # Measure CPU/memory utilization on dataplane pod
    SEARCH="$OPT"
    if [ "$OPT" == "calico" ]; then
        SEARCH="$OPT-node"
    fi
    CPU_USAGE=$(kubectl top pods -n kube-system | grep $SEARCH | awk '{print $2}' | head -n 1)
    MEM_USAGE=$(kubectl top pods -n kube-system | grep $SEARCH | awk '{print $3}' | head -n 1)
    
    # Parse throughput and retransmissionss
    parse_tcp

    # Log result into a CSV file
    LOG_FILE="results/tcp_test.csv"
    if [ ! -f "$LOG_FILE" ]; then
        echo "Network,Protocol,Duration (in seconds),Streams,Congestion Window,Throughput,Retransmissions,CPU,Memory,DateTime" > "$LOG_FILE"
    fi
    echo "$OPT,$PROTOCOL,$DURATION,$STREAMS,$CWND,$BITRATE,$RETRANSMITS,$CPU_USAGE,$MEM_USAGE,$(date +%Y-%m-%d_%H:%M:%S)" >> "$LOG_FILE"
fi

echo "Test completed. See results in $LOG_FILE."