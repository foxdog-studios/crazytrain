config = require('config')
logger = require('logger')
prettyjson = require('prettyjson')
StompClient = require('stomp-client').StompClient

dbUtils = require('./mongo_utils')


if config.log?
  log = logger.createLogger(config.log)
else
  log = logger.createLogger()

class TrustMessageParser
  constructor: (@db) ->
    @trainsCollection = @db.collection('trains')
    @statisticsCollection = @db.collection('statistics')

  parse: (message) ->
    switch message.header.msg_type
      when '0001' then @_parseTrainActivation(message)
      when '0003' then @_parseTrainMovement(message)
    @statisticsCollection.update _id: 'statistics',
        $set:
          lastMessageAt: new Date()
          lastMessage: message
      ,
        upsert: true
      , @_logError

  _logError: (error) ->
    if error?
      log.error error

  _parseTrainActivation: (message) ->
    body = message.body
    trainUid = body.train_uid
    scheduleStartDate = body.schedule_start_date
    scheduleType = body.schedule_type
    scheduleId = "#{trainUid}#{scheduleStartDate}"
    trainId = body.train_id
    @trainsCollection.save
        _id: trainId
        scheduleId: scheduleId
        scheduleType: scheduleType
        active: true
        dateAdded: new Date()
      , @_logError

  _parseTrainMovement: (message) ->
    body = message.body
    trainId = body.train_id
    @trainsCollection.update _id: trainId,
        $set:
          event_type: body.event_type
          variation_status: body.variation_status
          loc_stanox: body.loc_stanox
          reporting_stanox: body.reporting_stanox
          next_report_stanox: body.next_report_stanox
          next_report_run_time: body.next_report_run_time
          planned_timestamp: body.planned_timestamp
          actual_timestamp: body.actual_timestamp
          timetable_variation: body.timetable_variation
          train_terminated: body.train_terminated
      , @_logError


class NrodClient
  constructor: (username, password, @toc_code, @trustMessageParser) ->
    @destination = "/topic/TRAIN_MVT_#{@toc_code}_TOC"
    @client = new StompClient('datafeeds.networkrail.co.uk',
                              61618,
                              username,
                              password,
                              '1.0')
    @client.on 'disconnect', @onDisconnect

  connect: ->
    @client.connect @onConnection, @onError

  onDisconnect: ->
    log.info "#{@toc_code} feed disconnected"

  onConnection: (sessionId) =>
    log.info "Trying to connect with session id: #{sessionId} ..."
    log.info "Subscribing to #{@destination}"
    @client.subscribe @destination, @onSubscription

  onError: (error) =>
    log.error "Error in #{@toc_code} feed"
    log.error error
    throw error

  onSubscription: (body, headers) =>
    for message in JSON.parse(body)
      @trustMessageParser.parse(message)


main = ->
  username = config.datafeed.username
  password = config.datafeed.password
  toc_codes = config.datafeed.schedule_toc_codes
  for toc_code in toc_codes
    do (toc_code) ->
      dbUtils.getMongoDb (db) ->
        trustMessageParser = new TrustMessageParser(db)
        nrodClient = new NrodClient(username, password, toc_code,
                                    trustMessageParser)
        nrodClient.connect()


main()

