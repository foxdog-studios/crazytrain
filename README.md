crazytrain
==========

Network rail arrival &amp; departure server using
[network rail open data](http://datafeeds.networkrail.co.uk).


The project is composed of

- a meteor server that allows you to view and manage the data.

- a sciprt that imports the schedule data.

- a REST API that returns data for a node that can be used with the CitySDK

Config
------

    mkdir config
    cp templates/default.yml config/default.yml

Edit `config/default.yml` and put in your datafeeds.networkrail.co.uk username
and password.

Meteor site
-----------

    ./scripts/mrt.zsh




