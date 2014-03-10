Handlebars.registerHelper 'stationNameFromTiploc', (tiploc) ->
  TIPLOC_MAP[tiploc] or tiploc

Handlebars.registerHelper 'stationNameFromStanox', (stanox) ->
  STANOX_MAP[stanox] or stanox

