@getTodaysScheduleForTiploc = (tiploc, timeOffset) ->
  now = new Date()
  timeOffset or= 60
  getDateScheduleForTiploc(now, tiploc, timeOffset)

getOffsetDayOfWeek = (m) ->
  # Days runs starts with monday at index 0, javascript starts with sunday at
  # index 0. We need to shift it along
  (m.day() + 6) % 7

@getDateScheduleForTiploc = (date, tiploc, timeOffset) ->
  # FIXME: Retrieve schedules for trains that were schedules the previous day
  # but finish after midnight, i.e., day of week is the day before and the last
  # arrival time is after midnight.
  startDate = moment(date)
  endDate = startDate.clone().add('minutes', timeOffset)
  startTime = parseInt(startDate.format('HHmm'))
  endTime = parseInt(endDate.format('HHmm'))

  startDayOfWeek = getOffsetDayOfWeek(startDate)
  endDayOfWeek = getOffsetDayOfWeek(endDate)

  dayQuery = {}
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
    startDayQuery = {}
    startDayQuery["JsonScheduleV1.schedule_days_runs.#{startDayOfWeek}"] = true
    endDayQuery = {}
    endDayQuery["JsonScheduleV1.schedule_days_runs.#{endDayOfWeek}"] = true
    dayQuery =
      $or: [
        startDayQuery
      ,
        endDayQuery
      ]
  else
    timeQuery =
      tiploc_code: tiploc
      time:
        $gte: startTime
        $lte: endTime
    dayQuery["JsonScheduleV1.schedule_days_runs.#{startDayOfWeek}"] = true
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

@getArrivalAndDepartureTimes = (currentTiploc, scheduleCursor, date) ->
  date or= new Date()
  date = moment(date)
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
  nowTime = parseInt(date.format('HHmm'))
  # FIXME: Ensure this works for sorting times as we approach midnight.
  sortedSchedules = _.sortBy schedules, (schedule) ->
    if schedule.arrival?
      time = schedule.arrival
    else if schedule.departure?
      time = schedule.departure
    else
      return -1
    time
  return sortedSchedules

