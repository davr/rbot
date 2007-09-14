#-- vim:sw=2:et
#++
#
# :title: Twitter Status Update for rbot
#
# Author:: Carter Parks (carterparks) <carter@carterparks.com>
# Author:: Giuseppe "Oblomov" Bilotta <giuseppe.bilotta@gmail.com>
#
# Copyright:: (C) 2007 Carter Parks
#
# Users can setup their twitter username and password and then begin updating
# twitter whenever

require 'rexml/rexml'
require 'cgi'

class TwitterPlugin < Plugin
  def initialize
    super

    class << @registry
      def store(val)
        val
      end
      def restore(val)
        val
      end
    end

    @header = {
      'X-Twitter-Client' => 'rbot twitter plugin'
    }
  end

  # return a help string when the bot is asked for help on this plugin
  def help(plugin, topic="")
    return "twitter status [status] => updates your status on twitter | twitter identify [username] [password] => ties your nick to your twitter username and password"
  end

  # update the status on twitter
  def get_status(m, params)

    nick = params[:nick] || @registry[m.sourcenick + "_username"]

    if not nick
      m.reply "you should specify the username of the twitter touse, or identify using 'twitter identify [username] [password]'"
      return false
    end

    user = URI.escape(nick)

    # TODO configurable count
    uri = "http://twitter.com/statuses/user_timeline/#{user}.xml?count=3"

    response = @bot.httputil.get(uri, :headers => @header, :cache => false)
    debug response

    texts = []

    if response
      begin
        rex = REXML::Document.new(response)
        rex.root.elements.each("status") { |st|
          month, day, hour, min, sec, year = st.elements['created_at'].text.match(/\w+ (\w+) (\d+) (\d+):(\d+):(\d+) \S+ (\d+)/)[1..6]
          debug [year, month, day, hour, min, sec].inspect
          time = Time.local(year.to_i, month, day.to_i, hour.to_i, min.to_i, sec.to_i)
          now = Time.now
          delta = now - time
          msg = st.elements['text'].to_s + " (#{Utils.secs_to_string(delta.to_i)} ago via #{st.elements['source'].to_s})"
          texts << Utils.decode_html_entities(msg).ircify_html
        }
      rescue
        error $!
        m.reply "could not parse status for #{nick}"
        return false
      end
      m.reply texts.reverse.join("\n")
      return true
    else
      m.reply "could not get status for #{nick}"
      return false
    end
  end

  # update the status on twitter
  def update_status(m, params)


    unless @registry.has_key?(m.sourcenick + "_password") && @registry.has_key?(m.sourcenick + "_username")
      m.reply "you must identify using 'twitter identify [username] [password]'"
      return false
    end

    user = URI.escape(@registry[m.sourcenick + "_username"])
    pass = URI.escape(@registry[m.sourcenick + "_password"])
    uri = "http://#{user}:#{pass}@twitter.com/statuses/update.xml"

    body = "status=#{CGI.escape(params[:status].to_s)}"

    response = @bot.httputil.post(uri, body, :headers => @header)
    debug response

    if response.class == Net::HTTPOK
      m.reply "status updated"
    else
      m.reply "could not update status"
    end
  end

  # ties a nickname to a twitter username and password
  def identify(m, params)
    @registry[m.sourcenick + "_username"] = params[:username].to_s
    @registry[m.sourcenick + "_password"] = params[:password].to_s
    m.reply "you're all setup!"
  end
end

# create an instance of our plugin class and register for the "length" command
plugin = TwitterPlugin.new
plugin.map 'twitter identify :username :password', :action => "identify", :public => false
plugin.map 'twitter update *status', :action => "update_status", :threaded => true
plugin.map 'twitter status [:nick]', :action => "get_status", :threaded => true

