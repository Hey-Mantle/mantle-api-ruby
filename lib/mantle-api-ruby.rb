require 'net/http'
require 'uri'
require 'json'

class MantleClient
  attr_accessor :app_id, :api_key, :customer_api_token, :api_url

  # Initialize a new Mantle API client
  #
  # @param [String] app_id Your Mantle application ID
  # @param [String, nil] api_key Your Mantle API key (for server-side use only)
  # @param [String, nil] customer_api_token Customer-specific API token (for client-side use)
  # @param [String] api_url Base URL for the Mantle API
  # @return [MantleClient] A new instance of MantleClient
  # @raise [ArgumentError] If app_id is missing
  # @raise [ArgumentError] If both api_key and customer_api_token are missing
  # @raise [ArgumentError] If api_key is used in Rails frontend
  def initialize(app_id:, api_key: nil, customer_api_token: nil, api_url: 'https://appapi.heymantle.com/v1')
    raise ArgumentError, 'MantleClient app_id is required' unless app_id
    raise ArgumentError, 'MantleClient apiKey should never be used in the browser' if defined?(Rails) && api_key
    raise ArgumentError, 'MantleClient one of apiKey or customerApiToken is required' unless api_key || customer_api_token

    @app_id = app_id
    @api_key = api_key
    @customer_api_token = customer_api_token
    @api_url = api_url
  end

  # Make a request to the Mantle API
  #
  # @param [String] path The API endpoint path
  # @param [String] method The HTTP method ('GET', 'POST', 'PUT', 'DELETE')
  # @param [Hash, nil] body The request body (optional)
  # @return [Hash] The parsed JSON response
  # @raise [ArgumentError] If method is not supported
  # @raise [StandardError] If the API request fails
  def mantle_request(path:, method: 'GET', body: nil)
    uri = URI.join(@api_url, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-Mantle-App-Id' => @app_id
    }
    headers['X-Mantle-App-Api-Key'] = @api_key if @api_key
    headers['X-Mantle-Customer-Api-Token'] = @customer_api_token if @customer_api_token

    request = case method
              when 'GET'
                Net::HTTP::Get.new(uri, headers)
              when 'POST'
                Net::HTTP::Post.new(uri, headers)
              when 'PUT'
                Net::HTTP::Put.new(uri, headers)
              when 'DELETE'
                Net::HTTP::Delete.new(uri, headers)
              else
                raise ArgumentError, "Unsupported HTTP method: #{method}"
              end

    request.body = body.to_json if body

    response = http.request(request)
    JSON.parse(response.body)
  rescue => e
    puts "[mantleRequest] #{path} error: #{e.message}"
    raise e
  end

  # Identify a customer in Mantle
  #
  # @param [String, nil] platform_id Platform-specific identifier for the customer
  # @param [String, nil] access_token Platform-specific access token
  # @param [String, nil] name Customer's name
  # @param [String, nil] email Customer's email
  # @param [String, nil] myshopify_domain Shopify store domain
  # @param [String] platform Platform identifier ('shopify', 'web', 'mantle')
  # @param [Hash, nil] custom_fields Additional customer data
  # @return [Hash] The response from the Mantle API
  # @raise [ArgumentError] If required platform-specific identifiers are missing
  def identify(platform_id: nil, access_token: nil, name: nil, email: nil, myshopify_domain: nil, platform: 'shopify', custom_fields: nil)
    if platform == 'shopify' && platform_id.nil? && myshopify_domain.nil?
      raise ArgumentError, 'Either platform_id or myshopify_domain is required for Shopify platform'
    end

    if ['web', 'mantle'].include?(platform) && platform_id.nil?
      raise ArgumentError, 'platform_id is required for web and mantle platforms'
    end
    
    mantle_request(
      path: 'identify', 
      method: 'POST', 
      body: { 
        platformId: platform_id,
        myshopifyDomain: myshopify_domain,
        platform: platform,
        accessToken: access_token,
        name: name,
        email: email,
        customFields: custom_fields
      }.compact
    )
  end

  # Get the current customer's information
  #
  # @return [Hash] Customer data
  def get_customer
    mantle_request(path: 'customer')['customer']
  end

  # Create a new subscription
  #
  # @param [String, nil] return_url URL to redirect after subscription completion
  # @param [String, nil] discount_id ID of discount to apply
  # @param [String, nil] plan_id Single plan to subscribe to
  # @param [Array<String>, nil] plan_ids Multiple plans to subscribe to
  # @param [String] billing_provider Payment provider ('shopify', 'stripe', etc)
  # @return [Hash] The subscription response
  # @raise [ArgumentError] If neither plan_id nor plan_ids is provided
  # @raise [ArgumentError] If both plan_id and plan_ids are provided
  def subscribe(return_url: nil, discount_id: nil, plan_id: nil, plan_ids: nil, billing_provider: 'shopify')
    raise ArgumentError, 'Either plan_id or plan_ids must be provided' if plan_id.nil? && plan_ids.nil?
    raise ArgumentError, 'Cannot provide both plan_id and plan_ids' if plan_id && plan_ids

    mantle_request(
      path: 'subscriptions', 
      method: 'POST', 
      body: { 
        planId: plan_id,
        planIds: plan_ids,
        discountId: discount_id,
        returnUrl: return_url,
        billingProvider: billing_provider
      }.compact
    )
  end

  # Cancel the current subscription
  #
  # @param [String, nil] cancel_reason Reason for cancellation
  # @return [Hash] The cancellation response
  def cancel_subscription(cancel_reason: nil)
    mantle_request(
      path: 'subscriptions',
      method: 'DELETE',
      body: { cancelReason: cancel_reason }.compact
    )
  end

  # Update the capped amount for a subscription
  #
  # @param [String] id Subscription ID
  # @param [Integer] capped_amount New capped amount value
  # @return [Hash] The update response
  # @raise [ArgumentError] If id is missing
  # @raise [ArgumentError] If capped_amount is missing
  def update_subscription_capped_amount(id:, capped_amount:)
    raise ArgumentError, 'id is required' if id.nil?
    raise ArgumentError, 'capped_amount is required' if capped_amount.nil?

    mantle_request(
      path: 'subscriptions',
      method: 'PUT',
      body: { 
        id: id,
        cappedAmount: capped_amount
      }
    )
  end

  # Send a single usage event to Mantle
  #
  # @param [String] event_name The name of the event
  # @param [String, nil] customer_id Optional customer ID
  # @param [Time, String, nil] timestamp Optional timestamp for the event (optional)
  # @param [String, nil] event_id Idempotent identifier for the event (optional)
  # @param [Hash] properties Optional properties/metadata for the event (optional)
  # @return [Hash] The response from the Mantle API
  # @raise [ArgumentError] If event_name is nil
  def send_usage_event(event_name:, customer_id: nil, timestamp: nil, event_id: nil, properties: {})
    raise ArgumentError, 'event_name is required' if event_name.nil?

    mantle_request(
      path: 'usage_events',
      method: 'POST',
      body: { 
        eventId: event_id,
        eventName: event_name,
        customerId: customer_id,
        timestamp: timestamp,
        properties: properties
      }.compact
    )
  end

  # Send multiple usage events to Mantle in a single request
  #
  # @param [Array<Hash>] events Array of event objects. Each event should have at least an eventName
  # @option events [String] :event_name Name of the event (required)
  # @option events [String] :customer_id Customer ID (optional)
  # @option events [String] :event_id Idempotent identifier for the event (optional)
  # @option events [Time, String] :timestamp Timestamp for the event (optional)
  # @option events [Hash] :properties Properties/metadata for the event (optional)
  # @return [Hash] The response from the Mantle API
  # @raise [ArgumentError] If events is nil
  # @example Send multiple events
  #   client.send_usage_events(events: [
  #     { event_name: 'event1', properties: { amount: 100 } },
  #     { event_name: 'event2', properties: { amount: 200 } }
  #   ])
  def send_usage_events(events:)
    raise ArgumentError, 'events is required' if events.nil?

    # Convert each event's keys from snake_case to camelCase for the Mantle API
    formatted_events = events.map do |event|
      event.transform_keys do |key|
        key.to_s.gsub(/_([a-z])/) { $1.upcase }.to_sym
      end
    end

    mantle_request(
      path: 'usage_events',
      method: 'POST',
      body: { events: formatted_events }
    )
  end

  # Get invoices for the customer
  #
  # @param [Integer] page Page number for pagination (starts at 0)
  # @param [Integer] limit Number of invoices per page
  # @param [String, nil] customer_id Specific customer ID to fetch invoices for
  # @return [Hash] List of invoices and pagination info
  def get_invoices(page: 0, limit: 10, customer_id: nil)
    query_params = {
      page: page,
      limit: limit,
      customerId: customer_id
    }.compact

    path = "invoices"
    path += "?#{URI.encode_www_form(query_params)}" unless query_params.empty?
    
    mantle_request(path: path, method: 'GET')
  end

  # Get usage metric report
  #
  # @param [String] id Usage metric ID
  # @param [String, nil] customer_id Customer ID to filter metrics for
  # @param [String] period Aggregation period ('daily', 'weekly', 'monthly', 'yearly')
  # @param [String, nil] start_date Start date for the report
  # @param [String, nil] end_date End date for the report
  # @return [Hash] Usage metric report data
  # @raise [ArgumentError] If id is missing
  # @raise [ArgumentError] If period is invalid
  def usage_metric_report(id: nil, customer_id: nil, period: 'daily', start_date: nil, end_date: nil)
    raise ArgumentError, 'id is required' if id.nil?
    raise ArgumentError, 'period must be daily, weekly, monthly, or yearly' unless ['daily', 'weekly', 'monthly', 'yearly'].include?(period)

    query_params = {
      period: period,
      startDate: start_date,
      endDate: end_date,
      customerId: customer_id
    }.compact

    path = "usage_metric/#{id}/report"
    path += "?#{URI.encode_www_form(query_params)}" unless query_params.empty?
    
    mantle_request(path: path, method: 'GET')
  end
end
