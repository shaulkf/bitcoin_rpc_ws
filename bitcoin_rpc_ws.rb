require 'faye/websocket'
require 'eventmachine'
require 'uri'
require 'json'

class BitcoinWS
  def initialize(service_url)
    @url = service_url
  end

  def method_missing(name, *args)
    post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
    resp = ws_post_request(post_body)
    raise JSONRPCError, 'no response received' unless resp
    parsed_resp = JSON.parse(resp)
    raise JSONRPCError, parsed_resp['error'] if parsed_resp['error']
    parsed_resp['result']
  end

  def ws_post_request(post_body)
    response = nil
    EM.run {
      ws = Faye::WebSocket::Client.new(@url)

      ws.on :open do |event|
        p [:open]
        ws.send(post_body)
      end

      ws.on :message do |event|
        p [:message, event.data]
        response = event.data
        ws.close
      end

      ws.on :close do |event|
        p [:close, event.code, event.reason]
        ws = nil
        EM.stop
      end

      Signal.trap("INT")  { p [:INT] ; ws.close }
      Signal.trap("TERM") { p [:TERM]; ws.close }
    }
    return response
  end

  class JSONRPCError < RuntimeError; end
end

s = BitcoinWS.new('wss://username:password@127.0.0.1:18334/ws')
p s.getblockcount
p s.getnetworkhashps
