#!/bin/sh -e
# Copied and adjusted from https://github.com/riigipilv/apiexamples/blob/master/api/create_vm.sh

# -*- coding: utf-8; indent-tabs-mode: nil; tab-width: 4; -*-
##
# Creates and starts virtual machine instance using Waldur API.
#
# Based on
# https://opennode.atlassian.net/wiki/display/WD/Examples#Examples-CreationofanOpenStackInstance
#
# Requires: httpie, jq

flavor_name="m1.small"  # change to the one you prefer
http_opts="--check-status --ignore-stdin --print b --verbose"
image_name="CentOS 7 x86_64"  # change to the one you prefer
internal_network_name="marketplace-demo-int-net"  # lookup from OpenStack Tenant details
provider_name="marketplace-demo"  # lookup from Organization -> Providers (typically the same as Tenant name)
provider_uuid="8108bf871cd0428792f6474758bd422b"
ssh_key_name="ilja-key"  # user SSH key name, lookup from Profile - SSH Keys
system_volume_size_mb=20480  # size of system volume
waldur_api_url="https://api.riigipilv.ee"
auth_token=`cat auth_token`

sec_group_default_uuid="f9ed8d167c684aabbebd7bd7511d3346"
sec_group_default_url=$waldur_api_url/api/openstacktenant-security-groups/${sec_group_default_uuid}/
sec_group_web_uuid="df0aece425c847f19eac7c073d5d39c6"
sec_group_web_url=$waldur_api_url/api/openstacktenant-security-groups/${sec_group_web_uuid}/
sec_group_ssh_uuid="bd7d96caf6a74041951d35af0e97751d"
sec_group_ssh_url=$waldur_api_url/api/openstacktenant-security-groups/${sec_group_ssh_uuid}/

if [ $# -lt 1 ]; then
    echo "Usage: $(basename $0) <instance-name>"
    exit 1
fi

instance_name="$1"

settings_url=$(http $http_opts GET "$waldur_api_url/api/openstacktenant/" \
    Authorization:"token $auth_token" \
    name=="$provider_name" \
    | jq -r '.[0].settings')
if [ -z "$settings_url" ]; then
    echo "[ERROR] Failed to retrieve OpenStack provider '$provider_name' settings URL."
    exit 1
fi

image_url=$(http $http_opts GET "$waldur_api_url/api/openstacktenant-images/" \
    Authorization:"token $auth_token" \
    name=="$image_name" \
    settings=="$settings_url" \
    | jq -r '.[0].url')
if [ -z "$image_url" ]; then
    echo "[ERROR] Failed to retrieve instance image '$image_name' URL."
    exit 1
fi

flavor_url=$(http $http_opts GET "$waldur_api_url/api/openstacktenant-flavors/" \
    Authorization:"token $auth_token" \
    name=="$flavor_name" \
    settings=="$settings_url" \
    | jq -r '.[0].url')
if [ -z "$settings_url" ]; then
    echo "[ERROR] Failed to retrieve instance flavor '$flavor_name' URL."
    exit 1
fi

service_project_link_url=$(http $http_opts GET "$waldur_api_url/api/openstacktenant-service-project-link/?service_uuid=$provider_uuid" \
    Authorization:"token $auth_token" \
    | jq -r ".[] | select(.service_name == \"$provider_name\").url")
#http $http_opts GET "$waldur_api_url/api/openstacktenant-service-project-link/?service_uuid=$provider_uuid"  Authorization:"token $auth_token" | jq -r ".[]"
if [ -z "$service_project_link_url" ]; then
    echo "[ERROR] Failed to retrieve OpenStack service-project link URL for provider '$provider_name'."
    exit 1
fi

ssh_key_url=$(http $http_opts GET "$waldur_api_url/api/keys/" \
    Authorization:"token $auth_token" \
    name=="$ssh_key_name" \
    | jq -r '.[0].url')
if [ -z "$ssh_key_url" ]; then
    echo "[ERROR] Failed to retrieve SSH key '$ssh_key_name' URL."
    exit 1
fi

subnet_url=$(http $http_opts GET "$waldur_api_url/api/openstacktenant-networks/" \
    Authorization:"token $auth_token" \
    name=="$internal_network_name" \
    | jq -r '.[0].subnets | .[0]')
if [ -z "$subnet_url" ]; then
    echo "[ERROR] Failed to retrieve OpenStack project subnet '$internal_network_name' URL."
    exit 1
fi

#echo "Creating instance '$instance_name'..."
http $http_opts POST "$waldur_api_url/api/openstacktenant-instances/" \
    Authorization:"token $auth_token" \
    flavor="$flavor_url" \
    image="$image_url" \
    internal_ips_set:="[{\"subnet\":\"$subnet_url\"}]" \
    name="$instance_name" \
    service_project_link="$service_project_link_url" \
    ssh_public_key="$ssh_key_url" \
    system_volume_size:="$system_volume_size_mb" \
    floating_ips:="[{\"subnet\": \"$subnet_url\"}]" \
    security_groups:="[{\"url\": \"$sec_group_default_url\"}, {\"url\": \"$sec_group_web_url\"}, {\"url\": \"$sec_group_ssh_url\"}]" \
    | jq -r '.' &> /dev/null
#echo "Instance '$instance_name' created successfully."

#echo "Starting instance '$instance_name'..."
for i in $(seq 24); do
#    printf "."
    sleep 10
    [ "$i" -le 6 ] && continue  # do not poke Waldur first 60 seconds after instance is created
    instance_runtime_state=$(http $http_opts GET "$waldur_api_url/api/openstacktenant-instances/" \
        Authorization:"token $auth_token" \
        name=="$instance_name" \
        | jq -r '.[0].runtime_state')
    if [ "$instance_runtime_state" = "ACTIVE" ]; then
#        echo ""
        http $http_opts GET "$waldur_api_url/api/openstacktenant-instances/" \
        Authorization:"token $auth_token" name=="$instance_name" | jq -r '.[0].floating_ips[0].address'
        break
    fi
done
if [ "$instance_runtime_state" != "ACTIVE" ]; then
    echo "[ERROR] Failed to start instance '$instance_name', instance runtime_state: '$instance_runtime_state'." >&2
    exit 1
fi
