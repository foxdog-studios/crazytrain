#!/bin/env node

config = require('config')
logger = require('logger')
prettyjson = require('prettyjson')
StompClient = require('stomp-client').StompClient

log = logger.createLogger()

class TrustMessageParser
  parse: (message) ->
    switch message.header.msg_type
      when '0001' then _parseTrainActivation(message)
      when '0003' then _parseTrainMovement(message)

  _parseTrainActivation: (message) ->
    body = message.body
    trainUid = body.train_uid
    scheduleStartDate = body.schedule_start_date
    scheduleType = body.schedule_type
    scheduleId = "#{trainUid}#{scheduleStartDate}#{scheduleType}"
    trainId = body.train_id

  _parseTrainMovement: (message) ->



class NrodClient
  constructor: (username, password, toc_code) ->
    @destination = "/topic/TRAIN_MVT_#{toc_code}_TOC"
    @client = new StompClient('datafeeds.networkrail.co.uk',
                              61618,
                              username,
                              password,
                              '1.0')
  connect: ->
    @client.connect @onConnection

  onConnection: (sessionId) =>
    log.info "Trying to connect with session id: #{sessionId} ..."
    log.info "Subsribing to #{@destination}"
    @client.subscribe @destination, @onSubscription

  onSubscription: (body, headers) =>
    console.log(prettyjson.render(JSON.parse(body)))

main = ->
  username = config.datafeed.username
  password = config.datafeed.password
  toc_codes = config.datafeed.schedule_toc_codes
  nrodClient = new NrodClient(username, password, toc_codes[0])
  nrodClient.connect()

if require.main == module
  main()

