Meteor.publish 'tiplocs', ->
  Tiplocs.find {}, {limit: 10}

Meteor.publish 'schedules', ->
  Schedules.find {}, {limit: 10}

Meteor.publish 'stations', ->
  Stations.find {}, {limit: 10}

