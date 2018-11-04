#!/bin/bash
set -xe

SERVER_IP="163.172.105.216"
SSH_PORT="6969"
SSH_KEY_PATH="/home/etienne/.ssh/jeffries"

scp -P "$SSH_PORT" -i "$SSH_KEY_PATH" ./scripts/setup_machine.sh "root@$SERVER_IP:/tmp/setup_machine.sh"
scp -P "$SSH_PORT" -i "$SSH_KEY_PATH"  ./scripts/configure_os.sh "root@$SERVER_IP:/tmp/configure_os.sh"
scp -P "$SSH_PORT" -i "$SSH_KEY_PATH" "$SSH_KEY_PATH" "root@$SERVER_IP:/tmp/public_ssh_key"

ssh -p "$SSH_PORT" -i "$SSH_KEY_PATH" "root@$SERVER_IP" '/bin/bash /tmp/setup_machine.sh'
