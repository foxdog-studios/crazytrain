config = require('config')
mongo = require('mongodb')

@getMongoDb = (callback) ->
  onMongoConnect = (error, db) ->
    if error
      throw error
    callback(db)

  mongo.MongoClient.connect(
    "mongodb://#{config.mongo.host}:#{config.mongo.port}/#{config.mongo.name}",
    onMongoConnect)

