# Description:
#   Listens for event notifications from the ci-webhook listeners and handles Travis CI notifications

url           = require('url')
querystring   = require('querystring')
Entities      = require('html-entities').XmlEntities;
entities      = new Entities();

debug = false

module.exports = (robot) ->

  robot.router.post "/hubot/travis-ci", (req, res) ->
    try
      if (debug)
        robot.logger.info("Webhook received: ", req)

      data =
        payload     : req.body.payload
        query       : querystring.parse(url.parse(req.url).query)

      if (debug)
        robot.logger.info("Payload: ", data.payload)
      robot.emit "travis-ci-event", data
    catch error
      robot.logger.error "Webhook listener error: #{error.stack}. Request: #{req.body}"

    res.end ""

  robot.on "travis-ci-event", (event) ->
    data = JSON.parse event.payload

    # Only care about master notifications
    if (data.branch != "master")
      return

    if (data.type == "push")
      switch data.status_message
        when "Passed"
          robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Travis CI reports another successful master build - #{data.build_url}"
        when "Fixed"
          robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Relax, Travis CI reports, master build is working again - #{data.build_url}"
        when "Broken", "Failing", "Still Failing"
          robot.messageRoom process.env.HUBOT_IRC_ROOMS, "All hands on deck, Travis CI reports a broken master build - #{data.build_url}"
        else robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Unhandled build status message: #{data.status_message}"
      robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Commit by #{data.author_name}: #{data.message}"
      return

    if (data.type == "pull_request")
      switch data.status_message
        when "Passed", "Fixed"
          robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Travis CI reports, pull request https://github.com/minishift/minishift/pull/#{data.pull_request_number} completed successully"
        when "Broken", "Failing", "Still Failing"
          robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Travis CI reports, pull request https://github.com/minishift/minishift/pull/#{data.pull_request_number} is broken"
        else robot.messageRoom process.env.HUBOT_IRC_ROOMS, "Unhandled build status message: #{data.status_message}"
