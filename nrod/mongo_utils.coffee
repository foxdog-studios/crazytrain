config = require('config')
mongo = require('mongodb')

@getMongoDb = (callback) ->
  onMongoConnect = (error, db) ->
    if error
      console.error('Unable to connect to mongodb. Is it running?')
      throw error
    callback(db)

  mongo.MongoClient.connect(
    "mongodb://#{config.mongo.host}:#{config.mongo.port}/#{config.mongo.name}",
    onMongoConnect)

