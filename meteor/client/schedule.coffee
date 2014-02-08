getHoursMinutesFromTimestamp = (timestamp) ->
  moment(parseInt(timestamp)).format('HHmm')


Template.schedule.helpers
  isActive: ->
    train = Trains.findOne(scheduleId: @_id)
    if train?
      '✔'


  from: ->
    return @from if @from?
    return 'Starts here' if @to?
    return 'Passes'

  to: ->
    return @to if @to?
    return 'Terminates here' if @from?
    return 'Passes'

  realtimeData: ->
    train = Trains.findOne(scheduleId: @_id)
    return unless train?
    lastStanox = train.loc_stanox
    if lastStanox
      lastStation = Stations.findOne(stanox: lastStanox)
      if lastStation?
        train.lastSeen = lastStation.StationName
      else
        train.lastSeen = lastStanox
    nextStanox = train.next_report_stanox
    if nextStanox
      nextStation = Stations.findOne(stanox: nextStanox)
      if nextStation?
        train.goingTo = nextStation.StationName
      else
        train.goingTo = nextStanox
    actualTimestamp = train.actual_timestamp
    if actualTimestamp?
      train.actualTimestamp = getHoursMinutesFromTimestamp(actualTimestamp)
    plannedTimestamp = train.planned_timestamp
    if plannedTimestamp?
      train.plannedTimestamp = getHoursMinutesFromTimestamp(plannedTimestamp)
    terminated = train.train_terminated
    if terminated?
      train.terminated = terminated == 'true'
    train

