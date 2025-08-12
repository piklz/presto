#!/bin/sh

TEMPLATE_FILE="/app/glances.conf.template"
FINAL_CONFIG_FILE="/app/glances.conf"

if [ ! -f "$FINAL_CONFIG_FILE" ]; then
    echo "Glances config not found. Copying template."
    cp "$TEMPLATE_FILE" "$FINAL_CONFIG_FILE"
fi

exec glances -C "$FINAL_CONFIG_FILE" -w