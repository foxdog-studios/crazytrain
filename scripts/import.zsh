#!/bin/zsh

setopt err_exit

repo=${0:h}/../

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

cd $repo

# Clean old data
node ./bin/schedule_importer.js -e

# Import CORPUS
node ./bin/schedule_importer.js -c

# Import Rail Reference from NaPTAN
node ./bin/schedule_importer.js -r "${rail_reference}"

# Import SCHEDULE feeds
node ./bin/schedule_importer.js -d

