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
  day = (date.getDay() + 6) % 7
  dayQuery = {}
  dayQuery["JsonScheduleV1.schedule_days_runs.#{day}"] = true
  Schedules.find
    $and: [
      'JsonScheduleV1.schedule_segment.schedule_location':
        $elemMatch:
          tiploc_code: tiploc
          time:
            $gte: startTime
            $lte: endTime
    ,
      'JsonScheduleV1.schedule_start_date':
        $lt: date
    ,
      'JsonScheduleV1.schedule_end_date':
        $gt: date
    ,
      dayQuery
    ]

@getArrivalAndDepartureTimes = (currentTiploc, scheduleCursor) ->
  schedules = []
  scheduleCursor.forEach (rawSchedule) ->
    jsonScheduleV1 = rawSchedule.JsonScheduleV1
    locations = jsonScheduleV1.schedule_segment.schedule_location
    unless locations
      return
    schedule = {}
    schedule._id = rawSchedule._id
    schedule.atocCode = jsonScheduleV1.atoc_code
    [start, mid..., end] = locations
    if start.tiploc_code != currentTiploc
      startStation = Stations.findOne(TiplocCode: start.tiploc_code)
      if startStation?
        schedule.from = startStation.StationName
      else
        schedule.from = start.tiploc_code
    else
      schedule.from = null
      schedule.platform = start.platform
    if end.tiploc_code != currentTiploc
      endStation = Stations.findOne(TiplocCode: end.tiploc_code)
      if endStation?
        schedule.to = endStation.StationName
      else
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


