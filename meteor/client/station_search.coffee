Template.stationSearch.rendered = ->
  AutoCompletion.init("input#station-search");

Template.stationSearch.helpers
  stationName: ->
    currentTiploc = Session.get('currentTiploc')
    station = Stations.findOne(TiplocCode: currentTiploc)
    if station
      return station.StationName

Template.stationSearch.events
  'keyup input#station-search': ->
    AutoCompletion.autocomplete
      element: 'input#station-search'
      collection: Stations
      field: 'StationName'
      limit: 10
      sort:
        'StationName': 1
  'submit #station-form': (e) ->
    e.preventDefault()
    stationName = $('#station-search').val()
    console.log "station name #{stationName}"
    station = Stations.findOne(StationName: stationName)
    unless station?
      console.log "No station named #{stationName} :-("
      return
    Session.set('currentTiploc', station.TiplocCode)

