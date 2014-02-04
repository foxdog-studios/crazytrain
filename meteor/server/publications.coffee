Meteor.publish 'tiplocs', ->
  Tiplocs.find {}, {limit: 10}

Meteor.publish 'schedules', (tiploc) ->
  Schedules.find
    'JsonScheduleV1.schedule_segment.schedule_location':
      $elemMatch:
        tiploc_code: tiploc

Meteor.publish 'stations', ->
  Stations.find {}

