
schedulesHandle = {}

Template.trainTimes.created = ->
  Deps.autorun ->
    schedulesHandle = Meteor.subscribe 'schedules', Session.get('currentTiploc')

loaded = ->
  schedulesHandle.ready? and schedulesHandle.ready()

Template.trainTimes.helpers
  loaded: ->
    return loaded()
  schedules: ->
    return unless loaded()
    console.log 'scheduling'
    schedules = []
    currentTiploc = Session.get('currentTiploc')
    Schedules.find().forEach (schedule) ->
      locations = schedule.JsonScheduleV1.schedule_segment.schedule_location
      unless locations
        return
      schedule = {}
      [start, mid..., end] = locations
      if start.tiploc_code != currentTiploc
        startStation = Stations.findOne(TiplocCode: start.tiploc_code)
        if startStation?
          schedule.from = startStation.StationName
        else
          schedule.from = start.tiploc_code
      else
        schedule.from = 'Starts here'
      if end.tiploc_code != currentTiploc
        endStation = Stations.findOne(TiplocCode: end.tiploc_code)
        if endStation?
          schedule.to = endStation.StationName
        else
          schedule.to = end.tiploc_code
      else
        schedule.to = 'Terminates here'
      for loc in locations
        if loc.tiploc_code == currentTiploc
          schedule.arrival = loc.arrival
          schedule.departure = loc.departure
          break
      schedules.push schedule
    sortedSchedules = _.sortBy schedules, (schedule) ->
      if schedule.arrival?
        return schedule.arrival
      schedule.departure
    console.log 'done scheduling'
    return sortedSchedules


