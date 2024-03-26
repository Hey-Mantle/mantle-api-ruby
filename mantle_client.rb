require 'net/http'
require 'uri'
require 'json'

class MantleClient
  attr_accessor :app_id, :api_key, :customer_api_token, :api_url

  def initialize(app_id:, api_key: nil, customer_api_token: nil, api_url: 'https://appapi.heymantle.com/v1')
    raise ArgumentError, 'MantleClient app_id is required' unless app_id
    raise ArgumentError, 'MantleClient apiKey should never be used in the browser' if defined?(Rails) && api_key
    raise ArgumentError, 'MantleClient one of apiKey or customerApiToken is required' unless api_key || customer_api_token

    @app_id = app_id
    @api_key = api_key
    @customer_api_token = customer_api_token
    @api_url = api_url
  end

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

  def identify(platform_id:, myshopify_domain:, platform: 'shopify', access_token:, name:, email:, custom_fields: nil)
    mantle_request(path: 'identify', method: 'POST', body: { platform_id: platform_id, myshopify_domain: myshopify_domain, platform: platform, access_token: access_token, name: name, email: email, custom_fields: custom_fields })
  end

  def get_customer
    mantle_request(path: 'customer')['customer']
  end

  def subscribe(plan_id: nil, plan_ids: nil, discount_id:, return_url:, billing_provider: nil)
    mantle_request(path: 'subscriptions', method: 'POST', body: { plan_id: plan_id, plan_ids: plan_ids, discount_id: discount_id, return_url: return_url, billing_provider: billing_provider })
  end

  def cancel_subscription(cancel_reason: nil)
    mantle_request(path: 'subscriptions', method: 'DELETE', body: { cancel_reason: cancel_reason })
  end

  def update_subscription(id:, capped_amount:)
    mantle_request(path: 'subscriptions', method: 'PUT', body: { id: id, capped_amount: capped_amount })
  end

  def send_usage_event(event_id: nil, event_name:, customer_id:, properties: {})
    mantle_request(path: 'usage_events', method: 'POST', body: { event_id: event_id, event_name: event_name, customer_id: customer_id, properties: properties })
  end

  def send_usage_events(events:)
    mantle_request(path: 'usage_events', method: 'POST', body: { events: events })
  end
end
