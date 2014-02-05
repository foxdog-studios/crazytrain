Meteor.publish 'tiplocs', ->
  Tiplocs.find {}, {limit: 10}

Meteor.publish 'schedules', (tiploc) ->
  getTodaysScheduleForTiploc(tiploc)

Meteor.publish 'stations', ->
  Stations.find {}

