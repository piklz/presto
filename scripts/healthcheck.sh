#!/bin/bash

# Check if the WireGuard interface is up
if ip link show <interface-name> &> /dev/null ; then
    exit 0 # The interface is up, so the container is healthy
    echo -e "The interface is up, so the container is healthy"
else
    exit 1 # The interface is down, so the container is unhealthy
    echo -e "The interface is down, so the container is unhealthy"
fi