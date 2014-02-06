#!/bin/zsh

setopt err_exit

repo=${0:h}/..

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

# Import Rail Reference from NaPTAN
node ./bin/main.js -r "${rail_reference}"

# Import SCHEDULE feeds
node ./bin/main.js
