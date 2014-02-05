#!/bin/env node

async = require('async')
program = require('commander')
config = require('config')
csv = require('fast-csv')
fs = require('fs')
https = require('https')
logger = require('logger')
moment = require('moment')
mongo = require('mongodb')
OSPoint = require('ospoint')
util = require('util')
zlib = require('zlib')

PATH_TEMPLATE = \
  '/ntrod/CifFileAuthenticate?type=CIF_%s_TOC_FULL_DAILY&day=toc-full'

log = logger.createLogger()

logAndThrowError = (error) ->
  log.fatal error
  throw error


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

downloadSchedule = (callback, toc_code) ->
  buffer = []
  httpOptions =
    hostname: 'datafeeds.networkrail.co.uk'
    path: util.format(PATH_TEMPLATE, toc_code)
    auth: "#{config.datafeed.username}:#{config.datafeed.password}"
  req = https.request httpOptions, (res) ->
    if res.statusCode == 302
      newReq = https.request res.headers.location, (res) ->
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

importSchedule = (scheduleData, scheduleName, callback) ->
  entries = []
  scheduleEntries = []
  log.info "#{scheduleName}: reading scheduleData"
  ids = {}
  scheduleString = scheduleData.toString()
  log.info "#{scheduleName}: parsing schedule"
  lines = scheduleString.split('\n')
  numberOfLines = lines.length
  for line, i in lines
    if i % 1000 == 0
      log.info "#{scheduleName}: #{i}/#{numberOfLines} parsed"
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

  log.info "#{scheduleName}: #{entries.length} tiplocs to insert"
  log.info "#{scheduleName}: #{scheduleEntries.length} schedules to insert"
  insertDbEntries(entries, scheduleEntries, scheduleName, callback)

insertDbEntries = (tiplocEntries, scheduleEntries, scheduleName, callback) ->
  log.info "#{scheduleName}: inserting into db"
  getMongoDb (db) ->
    tiplocs = db.collection('tiplocs')
    tiplocs.insert tiplocEntries, (error, docs) ->
      log.info "#{scheduleName}: inserted tiplocs"
      schedules = db.collection('schedules')
      async.each scheduleEntries, schedules.save.bind(schedules), (error) ->
        if error?
          db.close()
          logAndThrowError error
        log.info "#{scheduleName}: inserted schedules"
        log.info "#{scheduleName}: closing db connection"
        # XXX: Set these to null to get the garbage collected. I am too dumb
        # to figure out the memory leak at the moment.
        # Without this it was grinding to a halt halfway through, probably
        # hitting swap space after it ran out of memory.
        tiplocEntries = null
        scheduleEntries = null
        db.close()
        callback()


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
          log.info 'stations inserted'
          db.close()
  ).parse()


################################################################################
#
# main
#
################################################################################

main = ->
  if program.railreference
    log.info "loading rail reference form #{program.railreference}"
    readRailReferenceCsv(program.railreference)
  else if program.schedules
    for schedule in program.schedules
      log.info "loading schedule from #{schedule}"
      fs.readFile schedule, (error, data) ->
        if error
          logAndThrowError error
        importSchedule(data, schedule)
  else
    downloadAndImport = (toc_code, callback) ->
      saveSchedule = (error, data) ->
        if error
          logAndThrowError error
        path = "/tmp/schedule-#{toc_code}.txt"
        fs.writeFile path, data, (error) ->
          if error
            logAndThrowError error
          log.info "Saved to #{path}"
          importSchedule data, toc_code, ->
            data = null
            callback()
      downloadSchedule(saveSchedule, toc_code)
    async.eachSeries config.datafeed.schedule_toc_codes, downloadAndImport, (error) ->
      if error
        logAndThrowError error
      console.log 'done'

if require.main == module
  main()

