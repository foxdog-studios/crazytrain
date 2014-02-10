Meteor.subscribe 'tiplocs'
Meteor.subscribe 'stations'
Meteor.subscribe 'statistics'

Meteor.startup ->
  Deps.autorun ->
    schedules = Schedules.find()
    ids = schedules.map (schedule) ->
      schedule._id
    Meteor.subscribe 'trains', ids

