AUTOCOMPLETE_SELECTOR = 'input#station-search'

Template.stationSearch.rendered = ->
  AutoCompletion.init(AUTOCOMPLETE_SELECTOR)
  $(AUTOCOMPLETE_SELECTOR).on('autocompleteselect', (e, ui) ->
    stationName = ui.item.value
    updateSchedule(stationName)
  )

Template.stationSearch.helpers
  stationName: ->
    currentTiploc = Session.get('currentTiploc')
    station = Stations.findOne(TiplocCode: currentTiploc)
    if station
      return station.StationName

searchHandle = null
STATION_SEARCH_MAX_NUM_RESULTS = 10
STATION_SEARCH_TIMEOUT_MS = 100

updateSchedule = (stationName) ->
  console.log "station name #{stationName}"
  station = Stations.findOne(StationName: stationName)
  unless station?
    console.log "No station named #{stationName} :-("
    return
  Session.set('currentTiploc', station.TiplocCode)

Template.stationSearch.events
  'keyup input#station-search': ->
    # Cancel any previous pending search
    if searchHandle?
      Meteor.clearTimeout(searchHandle)
    name = $(AUTOCOMPLETE_SELECTOR).val()
    # Require 3 or more characters to try and prevent searches
    # which will be too broad and be slow on mobiles.
    if name.length < 3
      return
    # Use a timeout to throttle the number of times the db is searched,
    # this is to increase responsiveness on mobiles (tested on Nexus 4).
    searchHandle = Meteor.setTimeout( ->
      AutoCompletion.autocomplete
        element: AUTOCOMPLETE_SELECTOR
        collection: Stations
        field: 'StationName'
        limit: STATION_SEARCH_MAX_NUM_RESULTS
        sort:
          'StationName': 1
    , STATION_SEARCH_TIMEOUT_MS)
  'submit #station-form': (e) ->
    e.preventDefault()
    stationName = $(AUTOCOMPLETE_SELECTOR).val()
    updateSchedule(stationName)

