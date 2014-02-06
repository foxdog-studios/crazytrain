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

RESTstop.add 'citysdk', ->
  node = @request.body
  tiploc = node.tiploc
  unless tiploc?
    return [403,
      message: 'You need to provide a tiploc'
    ]
  schedules = getTodaysScheduleForTiploc(tiploc)
  result = getArrivalAndDepartureTimes(tiploc, schedules)
  node.data = result
  return node

