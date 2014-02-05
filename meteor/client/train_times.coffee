
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
    currentTiploc = Session.get('currentTiploc')
    getArrivalAndDepartureTimes(currentTiploc, Schedules.find())

