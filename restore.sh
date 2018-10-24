#!/bin/sh

vm_name=$1

./1.build_opendata.riik.ee.sh
ip=$(./2.launch_opendata.riik.ee.sh $vm_name)
./3.deploy_opendata.riik.ee.sh $ip
