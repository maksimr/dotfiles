#!/usr/bin/env bash
# Run udot/pi updates in every container created by .local/bin/pix (name pi-*).
# Stopped containers are started, updated, then stopped again.
failed=0
for name in $(docker ps -a --filter name='^pi-' --format '{{.Names}}'); do
  echo "==> $name"
  was_running=$(docker inspect -f '{{.State.Running}}' "$name")
  [ "$was_running" = true ] || docker start "$name" >/dev/null
  docker exec "$name" udot update &&
    docker exec "$name" pi update &&
    docker exec "$name" pi update --extensions ||
    { echo "!! $name update failed" >&2; failed=1; }
  [ "$was_running" = true ] || docker stop "$name" >/dev/null
done
exit $failed
