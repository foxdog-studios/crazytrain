RESTstop.configure()
RESTstop.add 'trips/:tiploc?', ->
  tiploc = @params.tiploc
  unless tiploc?
    return [403,
      success: false
      message:'You need to provide a tiploc as a parameter'
    ]
  schedules = getTodaysScheduleForTiploc(tiploc)
  result = getArrivalAndDepartureTimes(tiploc, schedules)
  results: result

