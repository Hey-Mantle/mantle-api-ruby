# Mantle API Library for Ruby

A very basic Ruby library for accessing the Mantle API. Never give your Mantle API key to anyone, and never use it on the frontend or store it in source control!

### Example usage

```ruby
require 'mantle-api-ruby'

begin
  # Initialize the MantleClient with necessary parameters
  client = MantleClient.new(
    app_id: 'your_mantle_app_id',
    api_key: 'your_mantle_api_key', # Use nil if calling from the client-side
    customer_api_token: nil, # Use the customer's API token if calling from the client-side
    api_url: 'https://appapi.heymantle.com/v1'
  )

  # Example usage: Identify a customer
  customer_response = client.identify(
    platform_id: 'customer_platform_id',
    myshopify_domain: 'customer_shop.myshopify.com',
    access_token: 'platform_access_token',
    name: 'Customer Name',
    email: 'customer@example.com'
  )
  puts "Identified customer with API token: #{customer_response['apiToken']}"

  # Example usage: Get the customer associated with the current API token
  current_customer = client.get_customer
  puts "Current Customer: #{current_customer}"

  # Example usage: Subscribe a customer to a plan
  subscription_response = client.subscribe(
    plan_id: 'plan_identifier',
    discount_id: 'discount_identifier',
    return_url: 'https://yourapp.com/return_url_after_subscription',
    billing_provider: 'stripe' # or any other billing provider you support
  )
  puts "Subscription created: #{subscription_response}"

  # Example usage: Cancel a subscription
  cancellation_response = client.cancel_subscription(
    cancel_reason: 'customer_requested'
  )
  puts "Subscription cancelled: #{cancellation_response}"

  # Example usage: Update a subscription's capped amount
  update_response = client.update_subscription_capped_amount(
    id: 'subscription_identifier',
    capped_amount: 1000
  )
  puts "Subscription capped amount updated: #{update_response}"

  # Example usage: Send a usage event
  usage_response = client.send_usage_event(
    event_id: 'event_id',
    event_name: 'event_name',
    properties: { 'key' => 'value' }
  )
  puts "Usage event sent: #{usage_response}"

rescue StandardError => e
  puts "An error occurred: #{e.message}"
end
```
