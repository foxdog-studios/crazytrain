#!/bin/env node

async = require('async')
program = require('commander')
config = require('config')
csv = require('fast-csv')
fs = require('fs')
https = require('https')
moment = require('moment')
mongo = require('mongodb')
OSPoint = require('ospoint')
util = require('util')
zlib = require('zlib')

PATH_TEMPLATE = '/ntrod/CifFileAuthenticate?type=CIF_%s_TOC_FULL_DAILY&day=toc-full'

################################################################################
#
# Command line parsing
#
################################################################################

list = (val) ->
  return val.split(',')

program
  .version('0.0.1')
  .option('-s, --schedules <path_to_schedules>', 'schedule files', list)
  .option('-r, --railreference [path_to_rail_reference]',
          'NaPTAN rail reference')
  .parse(process.argv)


################################################################################
#
# Database
#
################################################################################

getMongoDb = (callback) ->
  onMongoConnect = (error, db) ->
    if error
      throw error
    callback(db)

  mongo.MongoClient.connect(
    "mongodb://#{config.mongo.host}:#{config.mongo.port}/#{config.mongo.name}",
    onMongoConnect)


################################################################################
#
# Network Rail datafeed SCHEDULE importing
#
################################################################################

getSchedule = (callback, toc_code) ->
  buffer = []
  options =
    hostname: 'datafeeds.networkrail.co.uk'
    path: util.format(PATH_TEMPLATE, toc_code)
    auth: "#{config.datafeed.username}:#{config.datafeed.password}"
  req = https.request options, (res) ->
    console.log res.statusCode
    if res.statusCode == 302
      newReq = https.request res.headers.location, (res) ->
        console.log res.statusCode
        gunzip = zlib.createGunzip()
        res.pipe(gunzip)
        gunzip.on('data', (data) ->
          # decompression chunk ready, add it to the buffer
          buffer.push(data.toString())
        ).on("end", ->
          # response and decompression complete, join the buffer and return
          callback(null, buffer.join(''))
        ).on("error", (e) ->
            callback(e)
        )
      newReq.end()
    console.log res.headers
    res.on 'data', (d) ->
      process.stdout.write(d)
  req.end()

daysRunToWeekArray = (daysRunString) ->
  for char in daysRunString
    char == '1'

getScheduleCompositeUID = (jsonScheduleV1) ->
  cifTrainUid = jsonScheduleV1['CIF_train_uid']
  scheduleStartDate = jsonScheduleV1['schedule_start_date']
  cifStopIndicator = jsonScheduleV1['CIF_stp_indicator']
  return "#{cifTrainUid}#{scheduleStartDate}#{cifStopIndicator}"


importSchedule = (scheduleData) ->
  entries = []
  scheduleEntries = []
  console.log 'reading lines'
  maxLength = 0
  max = null
  ids = {}
  for line in scheduleData.toString().split('\n')
    entry = JSON.parse(line)
    if entry['EOF']
      break
    if entry['TiplocV1']
      entry['_id'] = entry['TiplocV1']['tiploc_code']
      entries.push entry
    else if entry['JsonScheduleV1']
      jsonScheduleV1 = entry['JsonScheduleV1']
      entry['_id'] = getScheduleCompositeUID(jsonScheduleV1)
      startDate = jsonScheduleV1['schedule_start_date']
      jsonScheduleV1['schedule_start_date'] \
        = moment(startDate, 'YYYY-MM-DD').toDate()
      endDate = jsonScheduleV1['schedule_end_date']
      jsonScheduleV1['schedule_end_date'] \
        = moment(endDate, 'YYYY-MM-DD').toDate()
      daysRun = jsonScheduleV1['schedule_days_runs']
      daysRun = daysRunToWeekArray(daysRun)
      jsonScheduleV1['schedule_days_runs'] = daysRun
      scheduleEntries.push entry

  console.log "#{entries.length} tiplocs to insert"
  console.log "#{scheduleEntries.length} schedules to insert"
  insertDbEntries(entries, scheduleEntries)

insertDbEntries = (tiplocEntries, scheduleEntries) ->
  console.log 'inserting into db'
  getMongoDb (db) ->
    tiplocs = db.collection('tiplocs')
    tiplocs.insert tiplocEntries, (error, docs) ->
      console.log 'inserted the entries'
      schedules = db.collection('schedules')
      async.each scheduleEntries, schedules.save.bind(schedules), (error) ->
        if error?
          console.log error
        console.log 'closing db'
        db.close()


################################################################################
#
# NaPTAN rail reference importing
#
################################################################################

readRailReferenceCsv = (railReferenceCsv) ->
  rows = []
  csv(railReferenceCsv, headers: true)
    .on('data', (data) ->
      point = new OSPoint(data.Northing, data.Easting)
      latLon = point.toWGS84()
      data.latitude = latLon.latitude
      data.longitude = latLon.longitude
      data._id = data.TiplocCode
      rows.push(data)
    ).on('end', ->
      getMongoDb (db) ->
        stations = db.collection('stations')
        async.each rows, stations.save.bind(stations), (error) ->
          console.log 'stations inserted'
          db.close()
  ).parse()


################################################################################
#
# main
#
################################################################################

main = ->
  if program.railreference
    console.log "loading rail reference form #{program.railreference}"
    readRailReferenceCsv(program.railreference)
  else if program.schedules
    for schedule in program.schedules
      console.log "loading schedule from #{schedule}"
      fs.readFile schedule, (error, data) ->
        if error
          throw error
        importSchedule(data)
  else
    for toc_code in config.datafeed.schedule_toc_codes
      do (toc_code) ->
        saveSchedule = (error, data) ->
          if error
            console.log error
          path = "/tmp/schedule-#{toc_code}.txt"
          fs.writeFile path, data, (error) ->
            if error
              console.log error
            else
              console.log "Saved to #{path}"
        getSchedule(saveSchedule, toc_code)

if require.main == module
  main()

