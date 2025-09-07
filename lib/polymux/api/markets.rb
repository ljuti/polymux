require "polymux/client"

module Polymux
  module Api
    # API client for market status, schedules, and holiday information.
    #
    # Provides access to current market status and upcoming market holidays.
    # Essential for determining when markets are open for trading and planning
    # around market closures and early close days.
    #
    # @example Check current market status
    #   client = Polymux::Client.new
    #   markets = client.markets
    #
    #   status = markets.status
    #   puts "Market is #{status.open? ? 'open' : 'closed'}"
    #   puts "After hours trading: #{status.after_hours}"
    #
    # @example Check upcoming holidays
    #   holidays = markets.holidays
    #   next_holiday = holidays.first
    #   puts "Next market holiday: #{next_holiday.name} on #{next_holiday.date}"
    #
    # @see Status Market status data structure
    # @see Holidays Market holiday data structure
    class Markets < Polymux::Client::PolymuxRestHandler
      # Represents a market holiday or special trading schedule.
      #
      # Contains information about market closures and early close days,
      # including the specific exchange, date, and trading hours if applicable.
      # Useful for planning trading activities and understanding market availability.
      #
      # @example Check holiday impact
      #   holidays.each do |holiday|
      #     if holiday.closed?
      #       puts "Market closed on #{holiday.date} for #{holiday.name}"
      #     elsif holiday.early_close?
      #       puts "Early close on #{holiday.date}: closes at #{holiday.close}"
      #     end
      #   end
      class Holidays < Dry::Struct
        transform_keys(&:to_sym)

        # Date of the holiday or special schedule (YYYY-MM-DD format)
        # @return [String, nil] Holiday date
        attribute? :date, Types::String

        # Exchange affected by this holiday/schedule
        # @return [String, nil] Exchange identifier
        attribute? :exchange, Types::String

        # Name of the holiday or event
        # @return [String, nil] Holiday name (e.g., "Independence Day")
        attribute? :name, Types::String

        # Market opening time if different from normal hours
        # @return [String, nil] Opening time in HH:MM format
        attribute? :open, Types::String

        # Market closing time if different from normal hours
        # @return [String, nil] Closing time in HH:MM format
        attribute? :close, Types::String

        # Holiday status indicating the type of market impact
        # @return [String, nil] Status ("closed", "early-close", etc.)
        attribute? :status, Types::String

        # Check if the market is completely closed on this holiday.
        # @return [Boolean] true if market is closed all day
        def closed?
          status == "closed"
        end

        # Check if the market has early close on this holiday.
        # @return [Boolean] true if market closes early
        def early_close?
          status == "early-close"
        end
      end

      # Represents current market status and trading session information.
      #
      # Provides comprehensive information about the current state of various
      # markets including regular trading hours, extended hours, and pre-market
      # sessions. Also includes status for different asset classes and exchanges.
      #
      # @example Monitor trading sessions
      #   status = markets.status
      #
      #   case status.status
      #   when "open"
      #     puts "Regular trading hours"
      #   when "closed"
      #     puts "Market is closed"
      #   when "extended-hours"
      #     puts "Extended hours trading"
      #   end
      #
      #   puts "Pre-market active: #{status.pre_market}" if status.pre_market
      #   puts "After-hours active: #{status.after_hours}" if status.after_hours
      class Status < Dry::Struct
        transform_keys(&:to_sym)

        # Whether after-hours trading is currently active
        # @return [Boolean, nil] true if after-hours trading is available
        attribute? :after_hours, Types::Bool

        # Whether pre-market trading is currently active
        # @return [Boolean, nil] true if pre-market trading is available
        attribute? :pre_market, Types::Bool

        # Overall market status
        # @return [String, nil] Current status ("open", "closed", "extended-hours")
        attribute? :status, Types::String

        # Status information for currency markets
        # @return [Hash, nil] Currency market status details
        attribute? :currencies, Types::Hash

        # Status information for various exchanges
        # @return [Hash, nil] Exchange-specific status details
        attribute? :exchanges, Types::Hash

        # Status information for market indices
        # @return [Hash, nil] Indices market status details
        attribute? :indices, Types::Hash

        # Check if markets are completely closed.
        # @return [Boolean] true if all markets are closed
        def closed?
          status == "closed"
        end

        # Check if any markets are open (regular or extended hours).
        # @return [Boolean] true if markets are open in any capacity
        def open?
          status != "closed"
        end

        # Check if markets are in extended hours trading.
        # @return [Boolean] true if in extended hours session
        def extended_hours?
          status == "extended-hours"
        end

        # Create Status object from API response data.
        #
        # @param json [Hash] Raw market status data from API
        # @return [Status] Transformed status object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.market_status(json)
          new(attrs)
        end
      end

      # Get current market status across all exchanges and asset classes.
      #
      # Returns real-time information about market trading sessions including
      # regular hours, pre-market, and after-hours trading availability.
      # Essential for determining when trading is active.
      #
      # @return [Status] Current market status information
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Check trading availability
      #   status = markets.status
      #
      #   if status.open?
      #     puts "Markets are open for trading"
      #
      #     if status.extended_hours?
      #       puts "Currently in extended hours session"
      #     end
      #   else
      #     puts "Markets are closed"
      #   end
      #
      # @example Plan trading strategy
      #   unless status.open?
      #     puts "Waiting for market open..."
      #     puts "Pre-market available: #{status.pre_market}"
      #     puts "After-hours available: #{status.after_hours}"
      #   end
      def status
        request = _client.http.get("/v1/marketstatus/now")
        Status.from_api(request.body)
      end

      # Get upcoming market holidays and special schedules.
      #
      # Returns a list of upcoming market closures and early close days.
      # This information is crucial for planning trading activities and
      # understanding when markets will be unavailable.
      #
      # @return [Array<Holidays>] Array of upcoming holidays and special schedules
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Plan around holidays
      #   holidays = markets.holidays
      #
      #   holidays.each do |holiday|
      #     puts "#{holiday.date}: #{holiday.name}"
      #
      #     if holiday.closed?
      #       puts "  Market closed all day"
      #     elsif holiday.early_close?
      #       puts "  Early close at #{holiday.close}"
      #     end
      #   end
      #
      # @example Check for upcoming closures
      #   next_closure = holidays.find(&:closed?)
      #   if next_closure
      #     puts "Next market closure: #{next_closure.date} (#{next_closure.name})"
      #   end
      def holidays
        request = _client.http.get("/v1/marketstatus/upcoming")
        request.body.map do |holiday|
          Holidays.new(holiday)
        end
      end
    end
  end
end
