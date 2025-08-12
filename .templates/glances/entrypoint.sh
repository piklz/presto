#!/bin/sh

# The template is mounted from your host to this path
TEMPLATE_FILE="/app/glances.conf.template"

# The final config file is in the mounted volume
FINAL_CONFIG_FILE="/glances/conf/glances.conf"

# Only overwrite the config file if it's empty.
# This prevents overwriting user changes on a restart.
if [ ! -s "$FINAL_CONFIG_FILE" ]; then
    echo "Glances config is empty. Creating from template."
    envsubst < "$TEMPLATE_FILE" > "$FINAL_CONFIG_FILE"
fi

exec glances -C "$FINAL_CONFIG_FILE" -w