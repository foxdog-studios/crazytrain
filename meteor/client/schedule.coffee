Template.schedule.helpers
  isActive: ->
    train = Trains.findOne(scheduleId: @_id)
    if train?
      '✔'

  from: ->
    return @from if @from?
    return 'Starts here' if @to?
    return 'Passes'

  to: ->
    return @to if @to?
    return 'Terminates here' if @from?
    return 'Passes'

