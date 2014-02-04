async = require('async')
program = require('commander')
config = require('config')
csv = require('fast-csv')
fs = require('fs')
https = require('https')
mongo = require('mongodb')
OSPoint = require('ospoint')
zlib = require('zlib')

program
  .version('0.0.1')
  .option('-s, --schedule [path_to_schedule]', 'A gunzipped schedule file')
  .option('-r, --railreference [path_to_rail_reference]',
          'NaPTAN rail reference')
  .parse(process.argv)

getMongoDb = (callback) ->
  onMongoConnect = (error, db) ->
    if error
      throw error
    callback(db)

  mongo.MongoClient.connect(
    "mongodb://#{config.mongo.host}:#{config.mongo.port}/#{config.mongo.name}",
    onMongoConnect)

options =
  hostname: 'datafeeds.networkrail.co.uk'
  path: '/ntrod/CifFileAuthenticate?type=CIF_HF_TOC_FULL_DAILY&day=toc-full'
  auth: "#{config.datafeed.username}:#{config.datafeed.password}"

getSchedule = (callback) ->
  buffer = []
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
      id = entry['JsonScheduleV1']['CIF_train_uid']
      entry['_id'] = id
      scheduleEntries.push entry

  console.log "#{entries.length} tiplocs to insert"
  console.log "#{scheduleEntries.length} schedules to insert"
  console.log 'inserting into db'
  getMongoDb (db) ->
    tiplocs = db.collection('tiplocs')
    tiplocs.insert entries, (error, docs) ->
      console.log 'inserted the entries'
      schedules = db.collection('schedules')
      async.each scheduleEntries, schedules.save.bind(schedules), (error) ->
        if error?
          console.log error
        console.log 'ALL DONE closing db'
        db.close ->
          console.log 'goodbye'

readRailReferenceCsv = (railReferenceCsv) ->
  console.log 'safa'
  rows = []
  csv(railReferenceCsv, headers: true)
    .on('data', (data) ->
      point = new OSPoint(data.Northing, data.Easting)
      latLon = point.toWGS84()
      data.latitude = latLon.latitude
      data.longitude = latLon.longitude
      data._id = data.TiplocCode
      console.log(data)
      rows.push(data)
    ).on('end', ->
      getMongoDb (db) ->
        stations = db.collection('stations')
        async.each rows, stations.save.bind(stations), (error) ->
          console.log 'stations inserted'
          db.close()
  ).parse()

main = ->
  if program.railreference
    console.log "loading rail reference form #{program.railreference}"
    readRailReferenceCsv(program.railreference)
  else if program.schedule
    console.log "loading schedule from #{program.schedule}"
    fs.readFile program.schedule, (error, data) ->
      if error
        throw error
      importSchedule(data)
  else
    getSchedule (error, data) ->
      if error
        console.log error
      fs.writeFile '/tmp/schedule.txt', data, (error) ->
        if error
          console.log error
        else
          console.log 'Saved'

if require.main == module
  main()

