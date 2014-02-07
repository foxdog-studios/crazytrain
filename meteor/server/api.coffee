RESTstop.configure()

logger = new Logger('api')

RESTstop.add 'trips/:tiploc?', ->
  tiploc = @params.tiploc
  unless tiploc?
    return [403,
      success: false
      message:'You need to provide a tiploc as a parameter'
    ]
  logger.info("Request for #{tiploc}")
  schedules = getTodaysScheduleForTiploc(tiploc)
  result = getArrivalAndDepartureTimes(tiploc, schedules)
  results: result

RESTstop.add 'citysdk', ->
  node = @request.body
  # XXX: the JSON data comes in as the only key for an empty string. So we need
  # to extract it and parse it as JSON.
  node = JSON.parse(_.keys(node)[0])
  tiploc = node.tiploc_code
  logger.info("Request for #{tiploc}")
  unless tiploc?
    return [403,
      message: 'You need to provide a tiploc'
    ]
  schedules = getTodaysScheduleForTiploc(tiploc)
  result = getArrivalAndDepartureTimes(tiploc, schedules)
  node.data =
    times: result
  return node

