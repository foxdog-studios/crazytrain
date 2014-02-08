@getTodaysScheduleForTiploc = (tiploc, timeOffset) ->
  now = new Date()
  timeOffset or= 60
  getDateScheduleForTiploc(now, tiploc, timeOffset)

@getDateScheduleForTiploc = (date, tiploc, timeOffset) ->
  # Days runs starts with monday at index 0, javascript starts with sunday at
  # index 0. We need to shift it along
  m = moment(date)
  startTime = parseInt(m.format('HHmm'))
  endTime = parseInt(m.add('minutes', timeOffset).format('HHmm'))
  # Special after midnight case
  if endTime < startTime
    timeQuery =
      tiploc_code: tiploc
      $or: [
        time:
          $gte: startTime
      ,
        time:
          $lte: endTime
      ]
  else
    timeQuery =
      tiploc_code: tiploc
      time:
        $gte: startTime
        $lte: endTime

  day = (date.getDay() + 6) % 7
  dayQuery = {}
  dayQuery["JsonScheduleV1.schedule_days_runs.#{day}"] = true
  Schedules.find
    $and: [
      'JsonScheduleV1.schedule_segment.schedule_location':
        $elemMatch: timeQuery
    ,
      'JsonScheduleV1.schedule_start_date':
        $lt: date
    ,
      'JsonScheduleV1.schedule_end_date':
        $gt: date
    ,
      dayQuery
    ]


getHoursMinutesFromTimestamp = (timestamp) ->
  moment(parseInt(timestamp)).format('HHmm')

@getTrainDataFromSchedule = (schedule) ->
  train = Trains.findOne(scheduleId: schedule._id)
  return unless train?
  lastStanox = train.loc_stanox
  if lastStanox
    train.lastSeen = lastStanox
  nextStanox = train.next_report_stanox
  if nextStanox
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

@getArrivalAndDepartureTimes = (currentTiploc, scheduleCursor) ->
  schedules = []
  scheduleCursor.forEach (rawSchedule) ->
    jsonScheduleV1 = rawSchedule.JsonScheduleV1
    locations = jsonScheduleV1.schedule_segment.schedule_location
    unless locations
      return
    schedule = {}
    schedule._id = rawSchedule._id
    schedule.realtimeData = getTrainDataFromSchedule(schedule)
    schedule.atocCode = jsonScheduleV1.atoc_code
    [start, mid..., end] = locations
    if start.tiploc_code != currentTiploc
      schedule.from = start.tiploc_code
    else
      schedule.from = null
      schedule.platform = start.platform
    if end.tiploc_code != currentTiploc
      schedule.to = end.tiploc_code
    else
      schedule.to = null
      schedule.platform = end.platform
    for loc in locations
      if loc.tiploc_code == currentTiploc
        schedule.arrival = loc.arrival
        schedule.departure = loc.departure
        schedule.platform = loc.platform
        break
    schedules.push schedule
  sortedSchedules = _.sortBy schedules, (schedule) ->
    if schedule.arrival?
      return schedule.arrival
    schedule.departure
  return sortedSchedules


