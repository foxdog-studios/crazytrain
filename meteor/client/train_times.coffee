schedulesHandle = {}
schedulesHandleDependency = new Deps.Dependency()

Template.trainTimes.created = ->
  Deps.autorun ->
    schedulesHandle = Meteor.subscribe 'schedules', Session.get('currentTiploc')
    schedulesHandleDependency.changed()

loaded = ->
  schedulesHandleDependency.depend()
  schedulesHandle.ready? and schedulesHandle.ready()

Template.trainTimes.helpers
  loaded: ->
    return loaded()
  schedules: ->
    return unless loaded()
    currentTiploc = Session.get('currentTiploc')
    getArrivalAndDepartureTimes(currentTiploc, Schedules.find())

