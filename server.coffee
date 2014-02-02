#   Instagram real-time updates demo app.

url           = require 'url'
redis         = require 'redis'
settings      = require './settings'
helpers       = require './helpers'
subscriptions = require './subscriptions'
io            = require 'socket.io'

app = settings.app
app.get '/callbacks/tag/:tagName', (request, response) ->
  # The GET callback for each subscription verification.
  helpers.debug 'GET ' + request.url
  params = url.parse(request.url, true).query
  response.send params['hub.challenge'] or 'No hub.challenge present'

app.post '/callbacks/tag/:tagName', (request, response) ->
  tagName = request.params.tagName
  helpers.debug 'PUT /callbacks/tag/' + tagName

  # The POST callback for Instagram to call every time there's an update
  # to one of our subscriptions.

  # First, let's verify the payload's integrity
  unless helpers.isValidRequest(request)
    helpers.debug 'failed request validation'
    response.send 'FAIL'
    return

  # Go through and process each update. Note that every update doesn't
  # include the updated data - we use the data in the update to query
  # the Instagram API to get the data we want.
  updates = request.body
  for index of updates
    update = updates[index]
    helpers.processTag tagName if update['object'] is 'tag'
  helpers.debug 'Processed ' + updates.length + ' updates'
  response.send 'OK'

# Render the home page
app.get '/', (request, response) ->
  tagName = 'static'
  external_auth_url = settings.inst.oauth.authorization_url(
    scope: 'basic'
    display: 'touch'
  )
  authed = typeof request.session.instagram_access_token != 'undefined'
  helpers.debug request.session.access_token
  response.render 'tv.jade',
    tag: tagName,
    authed: authed
    external_auth_url: external_auth_url

app.get '/tag/:tagName', (request, response) ->
  tagName = request.params.tagName
  subscriptionCreated =
    helpers.maybeCreateSubscription(tagName, request.session.instagram_access_token)
  helpers.getMedia tagName, (error, tagName, media) ->
    response.json(
      tag: tagName,
      videos: media
    )

app.get '/:tagName', (request, response) ->
  tagName = request.params.tagName

  external_auth_url = settings.inst.oauth.authorization_url(
    scope: 'basic'
    display: 'touch'
  )
  authed = typeof request.session.instagram_access_token != 'undefined'
  helpers.debug request.session.access_token

  subscriptionCreated =
    helpers.maybeCreateSubscription(tagName, request.session.instagram_access_token)

  helpers.getMedia tagName, (error, tagName, media) ->
    response.render 'tv.jade',
      tag: tagName
      authed: authed
      external_auth_url: external_auth_url

app.get '/oauth/callback', (request, response) ->
  settings.inst.oauth.ask_for_access_token
    request: request
    response: response
    complete: (params, response) ->
      helpers.debug params
      request.session.instagram_access_token = params['access_token']
      request.session.instagram_user = params['user']
      response.redirect '/'
    error: (errorMessage, errorObject, caller, response) ->

