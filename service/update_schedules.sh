#!/bin/bash

set -o errexit

# Download NaPTAN if necessary
naptan_path=/tmp/naptan.zip

rail_reference=/tmp/naptan/RailReferences.csv

if [[ ! -a "${rail_reference}" ]]; then
    curl -o "${naptan_path}" http://www.dft.gov.uk/NaPTAN/snapshot/NaPTANcsv.zip
    cd /tmp
    mkdir -p naptan
    cd naptan/
    unzip -o "${naptan_path}"
fi

export NODE_ENV=production
export NODE_CONFIG_DIR=/etc/nrodstompclientservice

# Import CORPUS
/usr/bin/schedule_importer -c

# Import Rail Reference from NaPTAN
/usr/bin/schedule_importer -r "${rail_reference}"

# Import SCHEDULE feeds
/usr/bin/schedule_importer -d

