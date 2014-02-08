stationNameFromAttr = (attrKey, attrValue) ->
  query = {}
  query[attrKey] = attrValue
  station = Stations.findOne(query)
  if station
    station.StationName
  else
    attrValue

Handlebars.registerHelper 'stationNameFromTiploc', (tiploc) ->
  stationNameFromAttr('TiplocCode', tiploc)

Handlebars.registerHelper 'stationNameFromStanox', (stanox) ->
  stationNameFromAttr('stanox', stanox)

