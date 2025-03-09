#!/bin/bash
# Script to verify environment variables in Nginx processes

echo "Checking Nginx process environment variables..."

# Find the master process PID
MASTER_PID=$(pgrep -o nginx)
echo "Nginx master process PID: $MASTER_PID"

# Check environment variables in master process
MASTER_VARS=$(cat /proc/$MASTER_PID/environ 2>/dev/null | tr '\0' '\n' | grep -E "^(QKD_|OPENSSL)" | wc -l)
echo "QKD/OPENSSL variables in master process: $MASTER_VARS"

# Show some variables from master process
echo "Sample variables from master process:"
cat /proc/$MASTER_PID/environ 2>/dev/null | tr '\0' '\n' | grep -E "^(QKD_|OPENSSL)" | head -5

# Find a worker process PID
WORKER_PID=$(pgrep -f "nginx: worker" | head -1)
echo -e "\nNginx worker process PID: $WORKER_PID"

# Check environment variables in worker process
WORKER_VARS=$(cat /proc/$WORKER_PID/environ 2>/dev/null | tr '\0' '\n' | grep -E "^(QKD_|OPENSSL)" | wc -l)
echo "QKD/OPENSSL variables in worker process: $WORKER_VARS"

# Show some variables from worker process
echo "Sample variables from worker process:"
cat /proc/$WORKER_PID/environ 2>/dev/null | tr '\0' '\n' | grep -E "^(QKD_|OPENSSL)" | head -5

# For comparison, show variables in the container
SHELL_VARS=$(env | grep -E "^(QKD_|OPENSSL)" | wc -l)
echo -e "\nQKD/OPENSSL variables in container shell: $SHELL_VARS"
echo -e $(env | grep -E "^(QKD_|OPENSSL)" | wc -l)