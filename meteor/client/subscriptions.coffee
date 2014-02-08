Meteor.subscribe 'tiplocs'
Meteor.subscribe 'stations'

Meteor.startup ->
  Deps.autorun ->
    schedules = Schedules.find()
    ids = schedules.map (schedule) ->
      schedule._id
    Meteor.subscribe 'trains', ids

