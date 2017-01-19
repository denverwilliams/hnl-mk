#!/usr/bin/env ruby

# this is hnl_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)
#
#

# add the '/usr/local/lib/ruby' directory to the LOAD_PATH
# (this is where the hanlon_microkernel module files are placed by
# our Dockerfile)
$LOAD_PATH.unshift('/usr/local/lib/ruby')

require 'rubygems'
require 'net/http'
require 'cgi'
require 'json'
require 'webrick'
require 'hanlon_microkernel/hnl_mk_configuration_manager'
require 'hanlon_microkernel/logging'

# include the WEBrick mixin (makes this into a WEBrick server instance)
include WEBrick

# next, define our actions (as servlets)...for now we have one (used to
# save the Microkernel Configuration)

class MKConfigServlet < HTTPServlet::AbstractServlet

  def do_POST(req, res)
    # get a reference to the Configuration Manager instance (a singleton)
    config_manager = (HanlonMicrokernel::HnlMkConfigurationManager).instance

    # get the Hanlon URI from the request body; it should be included in
    # the body in the form of a string that looks something like the following:
    #
    #     "hanlonURI=<hanlon_uri_val>"
    #
    # where the hanlon_uri_val is a CGI-escaped version of the URI used by the
    # Hanlon server.  The "Registration Path" (from the uri_map, above) is added
    # to this Hanlon URI value in order to form the "registration_uri"
    json_string = CGI.unescapeHTML(req.body)
    logger.debug "in POST; configuration received...#{json_string.inspect}"
    # Note: have to truncate the CGI escaped body to get rid of the trailing '='
    # character (have no idea where this comes from, but it's part of the body in
    # a "post_form" request)
    config_map = JSON.parse(json_string)
    # create a new HTTP Response
    config = WEBrick::Config::HTTP
    resp = WEBrick::HTTPResponse.new(config)
    # check to see if the configuration has changed
    if config_manager.mk_config_has_changed?(config_map)
      # if the configuration has changed, then save the new configuration and restart the
      # Microkernel Controller (forces it to pick up the new configuration)
      config_manager.save_mk_config(config_map)
      logger.level = config_manager.mk_log_level
      logger.info "Config changed, restart the controller..."
      %x[sudo /usr/local/bin/hnl_mk_controller.rb restart]
      return_msg = 'New configuration saved, Microkernel Controller restarted'
      resp.content_type = 'text/plain'
      resp.content_length = return_msg.length
      resp.body = return_msg
      logger.debug "#{return_msg}..."
    else
      # otherwise, just log the fact that the configuration has not changed in the response
      resp.content_type = 'application/json'
      return_msg = 'Configuration unchanged; no update'
      resp.content_length = return_msg.length
      resp.body = JSON.generate({'json_received' => config_map,
                                 'message' => return_msg })
      logger.info "#{return_msg}..."
    end
  end

end

# set up a global variable that will be used in the HanlonMicrokernel::Logging mixin
# to determine where to place the log messages from this script
HNL_MK_LOG_PATH = "/var/log/hnl_mk_web_server.log"

# include the HanlonMicrokernel::Logging mixin (which enables logging)
include HanlonMicrokernel::Logging

# Now, create an HTTP Server instance (and Daemonize it)

s = HTTPServer.new(:Port => 2156, :Logger => logger, :ServerType => WEBrick::Daemon, :BindAddress => "127.0.0.1")

# mount our servlets as directories under our HTTP server's URI

s.mount("/setMkConfig", MKConfigServlet)

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start out server

s.start
