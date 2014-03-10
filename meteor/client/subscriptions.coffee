Meteor.subscribe 'tiplocs'
Meteor.subscribe 'stations'
Meteor.subscribe 'statistics'

@TIPLOC_MAP = {}
@STANOX_MAP = {}

Meteor.startup ->

  Deps.autorun (computation) ->
    # Create a lookup hash for stations by tiplocs and stanox
    # TODO: Make these reactive or just properly static.
    stations = Stations.find()
    stations.forEach (station) ->
      TIPLOC_MAP[station.TiplocCode] = station.StationName
      STANOX_MAP[station.stanox] = station.StationName

  Deps.autorun ->
    schedules = Schedules.find()
    ids = schedules.map (schedule) ->
      schedule._id
    Meteor.subscribe 'trains', ids

