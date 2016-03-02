# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "logstash/filters/data_dictionary"
require "logstash/filters/fix_message"

module LogStash
  module  Filters
    class FixProtocol < LogStash::Filters::Base

      attr_reader :data_dictionary, :session_dictionary

      config_name "fix_protocol"

      config :fix_message, validate: :string, default: "message"

      config :data_dictionary_path, validate: :string, default: "/PATH/TO/YOUR/DD"
      config :session_dictionary_path, validate: :string, default: nil

      def initialize(options = {})
        super(options)

        fail "Need to configure a valid data dictionary path" unless config["data_dictionary_path"]

        @data_dictionary = DataDictionary.new(config["data_dictionary_path"])

        # Set session data dictionary variable if using > FIX 5.0
        session_dict = config["session_dictionary_path"]
        @session_dictionary = session_dict.present? ? DataDictionary.new(session_dict) : @data_dictionary
      end

      def register
        # just here because you complain otherwise
      end

      def filter(event)
        message_string = event[config["fix_message"]]

        if message_string
          fix_message = nil

          begin
            fix_message = FixMessage.new(message_string, data_dictionary, session_dictionary)
          rescue Java::Quickfix::InvalidMessage, ArgumentError
            event["tags"] = ["_fix_parse_failure"]
          end

          if fix_message
            fix_hash = fix_message.to_hash

            fix_hash.each do |key, value|
              begin
                event[key] = value
              rescue NoMethodError => e
                puts "********"
                puts "WARNING: Could not correctly parse #{event["fix_message"]}"
                puts JSON.pretty_generate(fix_hash)
                puts "Message: #{e.message}"
                puts "********"
              ensure
                next
              end
            end
          end
        end
        # filter_matched should go in the last line of our successful code
        filter_matched(event)
      end
    end
  end
end
