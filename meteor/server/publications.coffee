Meteor.publish 'tiplocs', ->
  Tiplocs.find {}, {limit: 10}

Meteor.publish 'schedules', (tiploc) ->
  getTodaysScheduleForTiploc(tiploc)

Meteor.publish 'stations', ->
  Stations.find {}

Meteor.publish 'statistics', ->
  Statistics.find {}

Meteor.publish 'trains', (scheduleIds) ->
  return unless scheduleIds?
  Trains.find(scheduleId: $in: scheduleIds)

