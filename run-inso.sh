#!/bin/bash

echo "Inso version: $(./inso --version)"

mkdir -p results

pids=()
for i in $(seq 1 2); do
    LOG_FILE="results/inso_runner_${i}.log"
    JSON_FILE="results/inso_runner_${i}.json"
    XML_FILE="results/inso_runner_${i}.xml"
    CSV_FILE="results/inso_runner_${i}.csv"

    # Run the test and save raw log output
    ./inso run collection \
    --workingDir ./collections/test.yaml \
    --env QA \
    --env-var "token=$(gcloud auth print-identity-token)" \
    -n 1 \
    apmena-cdps-dgt-apac \
    > "$LOG_FILE"

    # Extract key data from log
    STATUS=$(grep "status=" "$LOG_FILE" | awk '{print $NF}' | cut -d'=' -f2)
    RESPONSE_TIME=$(grep "expected" "$LOG_FILE" | awk '{print $4}')

    # Generate JSON
    echo "{
      \"request\": \"getconsumer/LUCID\",
      \"status\": \"$STATUS\",
      \"response_time\": \"$RESPONSE_TIME ms\"
    }" > "$JSON_FILE"

    # Generate XML
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <testsuite name=\"Insomnia API Tests\">
        <testcase name=\"getconsumer/LUCID\">
            <status>$STATUS</status>
            <responseTime>$RESPONSE_TIME ms</responseTime>
        </testcase>
    </testsuite>" > "$XML_FILE"

    # Generate CSV
    echo "request,status,response_time" > "$CSV_FILE"
    echo "getconsumer/LUCID,$STATUS,$RESPONSE_TIME ms" >> "$CSV_FILE"

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
