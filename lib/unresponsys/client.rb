require 'httparty'

class Unresponsys
  class Client
    def initialize(options = {})
      raise Unresponsys::ArgumentError unless options[:username] && options[:password]
      @username = options[:username]
      @password = options[:password]
      @debug    = options[:debug]
      @logger   = Logger.new(STDOUT) if @debug
      @log_opts = { logger: @logger, log_level: :debug, log_format: :curl }
      authenticate
    end

    def get(path, options = {}, &block)
      path      = "#{@base_uri}#{path}"
      options   = @options.merge(options)
      options   = options.merge(@log_opts) if @debug
      response  = HTTParty.get(path, options, &block)
      handle_error(response)
    end

    def post(path, options = {}, &block)
      path      = "#{@base_uri}#{path}"
      options   = @options.merge(options)
      options   = options.merge(@log_opts) if @debug
      response  = HTTParty.post(path, options, &block)
      handle_error(response)
    end

    def delete(path, options = {}, &block)
      path      = "#{@base_uri}#{path}"
      options   = @options.merge(options)
      options   = options.merge(@log_opts) if @debug
      response  = HTTParty.delete(path, options, &block)
      handle_error(response)
    end

    def folders
      @folders ||= Folders.new(self)
    end

    def lists
      @lists ||= Lists.new(self)
    end

    class Folders
      def initialize(client)
        @client = client
      end

      def find(folder_name)
        Folder.new(@client, folder_name)
      end
    end

    class Lists
      def initialize(client)
        @client = client
      end

      def find(list_name)
        List.new(@client, list_name)
      end
    end

    private

    def handle_error(response)
      # newer versions of httparty response object
      # do not return true for .is_a?(Hash)
      # so use the parsed response instead - ckh 12/7/17
      pres = response.parsed_response
      if pres.is_a?(Hash) && pres.keys.include?('errorCode')
        case pres['errorCode']
        when /TOKEN_EXPIRED/
          raise Unresponsys::TokenExpired, pres['detail']
        when /NOT_FOUND/
          raise Unresponsys::NotFound, pres['detail']
        when /LIMIT_EXCEEDED/
          raise Unresponsys::LimitExceeded, pres['detail']
        else
          raise Unresponsys::Error, "#{pres['title']}: #{pres['detail']}"
        end
      end
      response
    end

    def authenticate
      headers   = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      body      = { user_name: @username, password: @password, auth_type: 'password' }
      response  = HTTParty.post('https://login2.responsys.net/rest/api/v1/auth/token', headers: headers, body: body)

      raise Unresponsys::AuthenticationError unless response.success?

      @options  = { headers: { 'Authorization' => response['authToken'], 'Content-Type' => 'application/json' } }
      @base_uri = "#{response['endPoint']}/rest/api/v1.1"
    end
  end
end
