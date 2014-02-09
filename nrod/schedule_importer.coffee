#!/bin/env node

async = require('async')
program = require('commander')
config = require('config')
csv = require('fast-csv')
fs = require('fs')
https = require('https')
logger = require('logger')
moment = require('moment')
OSPoint = require('ospoint')
util = require('util')
zlib = require('zlib')

dbUtils = require('./mongo_utils')

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
  .option('-c, --downloadcorpus')
  .option('-d, --downloadschedules')
  .option('-e, --removeold')
  .option('-s, --schedules <path_to_schedules>', 'schedule files', list)
  .option('-r, --railreference [path_to_rail_reference]',
          'NaPTAN rail reference')
  .parse(process.argv)


################################################################################
#
# Network Rail datafeed SCHEDULE importing
#
################################################################################

downloadNrodData = (path, callback) ->
  buffer = []
  httpOptions =
    hostname: 'datafeeds.networkrail.co.uk'
    path: path
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
  return "#{cifTrainUid}#{scheduleStartDate}"

getTiplocToStanoxMap = (callback) ->
  dbUtils.getMongoDb (db) ->
    tiplocToStanoxCollection = db.collection('tiplocToStanox')
    cursor = tiplocToStanoxCollection.find({})
    cursor.toArray (error, tiplocToStanoxes) ->
      if error?
        logAndThrowError error
      tiplocToStanoxMap = {}
      for tiplocToStanox in tiplocToStanoxes
        tiplocToStanoxMap[tiplocToStanox._id] = tiplocToStanox.stanox
      callback(tiplocToStanoxMap)
      db.close()

importSchedule = (scheduleData, scheduleName, callback) ->
  getTiplocToStanoxMap (tiplocToStanoxMap) ->
    importScheduleFromMap(scheduleData, scheduleName, tiplocToStanoxMap,
                          callback)


importScheduleFromMap = (scheduleData, scheduleName, tiplocToStanoxMap, callback) ->
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
      # TODO: Validity see http://nrodwiki.rockshore.net/index.php/SCHEDULE
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

      scheduleSegment = jsonScheduleV1['schedule_segment']
      scheduleLocations = scheduleSegment['schedule_location']

      if scheduleLocations?
        for scheduleLocation in scheduleLocations
          tiploc = scheduleLocation.tiploc_code
          stanox = tiplocToStanoxMap[tiploc]
          scheduleLocation.stanox = stanox

          timeKeys = ['departure', 'public_departure', 'arrival', 'pass']
          for timeKey in timeKeys
            if scheduleLocation[timeKey]?
              scheduleLocation[timeKey] = parseInt(scheduleLocation[timeKey])
          # time is used for searching for train times, they are ordered in
          # preference. I.e. the time of a train is when it arrives, then if
          # it does not have an arrival time it could be starting, then the
          # departure time is important. Else it could just be passing.
          if scheduleLocation['arrival']
            scheduleLocation['time'] = scheduleLocation['arrival']
          else if scheduleLocation['departure']
            scheduleLocation['time'] = scheduleLocation['departure']
          else if scheduleLocation['pass']
            scheduleLocation['time'] = scheduleLocation['pass']

      scheduleEntries.push entry

  log.info "#{scheduleName}: #{entries.length} tiplocs to insert"
  log.info "#{scheduleName}: #{scheduleEntries.length} schedules to insert"
  insertDbEntries(entries, scheduleEntries, scheduleName, callback)

insertDbEntries = (tiplocEntries, scheduleEntries, scheduleName, callback) ->
  log.info "#{scheduleName}: inserting into db"
  dbUtils.getMongoDb (db) ->
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
  getTiplocToStanoxMap (tiplocToStanoxMap) ->
    readRailReferenceCsvFromTiplocStanoxMap(railReferenceCsv, tiplocToStanoxMap)

readRailReferenceCsvFromTiplocStanoxMap = (railReferenceCsv,
                                           tiplocToStanoxMap) ->
  rows = []
  csv(railReferenceCsv, headers: true)
    .on('data', (data) ->
      point = new OSPoint(data.Northing, data.Easting)
      latLon = point.toWGS84()
      data.latitude = latLon.latitude
      data.longitude = latLon.longitude
      tiploc = data.TiplocCode
      data.stanox = tiplocToStanoxMap[tiploc]
      data._id = data.TiplocCode
      rows.push(data)
    ).on('end', ->
      dbUtils.getMongoDb (db) ->
        stations = db.collection('stations')
        async.each rows, stations.save.bind(stations), (error) ->
          log.info 'stations inserted'
          db.close()
  ).parse()

################################################################################
#
# Network rail CORPUS importing for STANOX -> TIPLOC matching
#
################################################################################

importCorpus = (corpusData) ->
  dbUtils.getMongoDb (db) ->
    corpus = JSON.parse(corpusData)
    tiplocData = corpus.TIPLOCDATA
    tiplocToStanox = for tiplocDatum in tiplocData
      stanox = tiplocDatum.STANOX
      tiploc = tiplocDatum.TIPLOC
      # Empty values are spaces
      continue if stanox == ' ' or tiploc == ' '
      stanox: stanox, _id: tiploc
    tiplocToStanoxCollection = db.collection('tiplocToStanox')
    upsert = (tiplocToStanox, callback) ->
      tiplocToStanoxCollection.update(
          _id: tiplocToStanox._id
        ,
          _id: tiplocToStanox._id
          stanox: tiplocToStanox.stanox
        ,
          upsert: true
        , callback
      )
    async.each tiplocToStanox, upsert.bind(tiplocToStanoxCollection), (error) ->
      log.info 'tiplocToStanox inserted'
      db.close()


################################################################################
#
# main
#
################################################################################

removeOldRecords = ->
  dbUtils.getMongoDb (db) ->
    schedules = db.collection('schedules')

downloadCorpus = ->
  saveCorpus = (error, data) ->
    if error
      logAndThrowError
    path = '/tmp/corpus.json'
    fs.writeFile path, data, (error) ->
      if error
        logAndThrowError error
      log.info "Save corpus to #{path}"
      importCorpus(data)
  downloadNrodData('/ntrod/SupportingFileAuthenticate?type=CORPUS',
                   saveCorpus)

main = ->
  if program.removeold
    removeOldRecords()
  if program.railreference
    log.info "loading rail reference form #{program.railreference}"
    readRailReferenceCsv(program.railreference)
  if program.schedules
    for schedule in program.schedules
      log.info "loading schedule from #{schedule}"
      fs.readFile schedule, (error, data) ->
        if error
          logAndThrowError error
        importSchedule data, schedule ->
          log.info "all done"
  if program.downloadschedules
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
      path = util.format(PATH_TEMPLATE, toc_code)
      downloadNrodData(path, saveSchedule)
    async.eachSeries config.datafeed.schedule_toc_codes, downloadAndImport, (error) ->
      if error
        logAndThrowError error
      console.log 'done'
  if program.downloadcorpus
    downloadCorpus()

main()

