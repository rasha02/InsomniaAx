#!/bin/bash

echo "Inso version: $(./inso --version)"

mkdir -p results

NUM_ITERATIONS=4  # number of -n iterations per runner

pids=()
for i in $(seq 1 5); do
    LOG_FILE="results/inso_runner_${i}.log"
    JSON_FILE="results/inso_runner_${i}.json"
    XML_FILE="results/inso_runner_${i}.xml"
    CSV_FILE="results/inso_runner_${i}.csv"

    # Run the test and save raw log output
    ./inso run collection \
    --workingDir ./collections/test.yaml \
    --env QA \
    --env-var "token=$(gcloud auth print-identity-token)" \
    -n $NUM_ITERATIONS \
    apmena-cdps-dgt-apac \
    > "$LOG_FILE"

    # Extract all statuses from "status=200"
    STATUSES=($(grep -oP 'status=\d+' "$LOG_FILE" | cut -d'=' -f2))

    # Extract all response times from "expected <time> to be below" lines (failures)
    RESPONSE_TIMES=($(grep -oP 'expected \K[0-9.]+' "$LOG_FILE"))

    # Initialize CSV, JSON, and XML outputs
    echo "request,iteration,status,response_time" > "$CSV_FILE"

    echo "[" > "$JSON_FILE"
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$XML_FILE"
    echo "<testsuite name=\"Insomnia API Tests\">" >> "$XML_FILE"

    for j in $(seq 0 $((NUM_ITERATIONS - 1))); do
        STATUS=${STATUSES[$j]:-"UNKNOWN"}

        # Default to UNKNOWN if no response time (e.g., if all tests passed)
        RESPONSE_TIME=${RESPONSE_TIMES[$j]:-"UNKNOWN"}

        # Append to CSV
        echo "getconsumer/LUCID,$((j + 1)),$STATUS,$RESPONSE_TIME ms" >> "$CSV_FILE"

        # Append to JSON
        if [[ $j -gt 0 ]]; then
            echo "," >> "$JSON_FILE"
        fi
        echo "  {\"iteration\": $((j + 1)), \"request\": \"getconsumer/LUCID\", \"status\": \"$STATUS\", \"response_time\": \"$RESPONSE_TIME ms\"}" >> "$JSON_FILE"

        # Append to XML
        echo "  <testcase name=\"getconsumer/LUCID (iteration $((j + 1)))\">" >> "$XML_FILE"
        echo "    <status>$STATUS</status>" >> "$XML_FILE"
        echo "    <responseTime>$RESPONSE_TIME ms</responseTime>" >> "$XML_FILE"
        echo "  </testcase>" >> "$XML_FILE"
    done

    echo "]" >> "$JSON_FILE"
    echo "</testsuite>" >> "$XML_FILE"

    echo "Reports generated: $JSON_FILE, $XML_FILE, $CSV_FILE"

    pids[${i}]=$!
done

# Wait for all processes
i=0
for pid in ${pids[*]}; do
    echo "Waiting for runner #$((++i)) with pid=$pid"
    wait $pid
    echo "Runner #${i} ended"
done
