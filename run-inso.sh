echo Inso version: $(./inso --version)

# start runners and store pids in array
pids=()
for i in `seq 1 5`; do
    ./inso run collection \
    --workingDir ./collections/test.yaml `# exported workspace` \
    --env QA `# environment to use` \
    --env-var "token=$(gcloud auth print-identity-token)" `# env vars to overwrite` \
    -n 5 `# the number of run iteration for this runner` \
    apmena-cdps-dgt-apac `# collection to run` \
    --reporter list \
    > results/inso_runner_${i}.log & `# detach and start next runner`
    pids[${i}]=$!
done

# wait for all pids
i=0
for pid in ${pids[*]}; do
    echo "Waiting for runner #$((++i)) with pid=$pid"
    wait $pid
    echo "Runner #${i} ended"
done
