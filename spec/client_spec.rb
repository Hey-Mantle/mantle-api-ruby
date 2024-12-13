require 'spec_helper'

RSpec.describe MantleClient do
  # @!method app_id
  #   @return [String]
  let(:app_id) { 'test_app_id' }
  
  # @!method api_key
  #   @return [String]
  let(:api_key) { 'test_api_key' }
  
  # @!method customer_api_token
  #   @return [String]
  let(:customer_api_token) { 'test_customer_token' }
  
  # @!method api_url
  #   @return [String]
  let(:api_url) { 'https://appapi.heymantle.com/v1' }

  # @!method client
  #   @return [MantleClient]
  let(:client) { MantleClient.new(app_id: app_id, api_key: api_key, api_url: api_url) }

  describe '#initialize' do
    it 'initializes with required parameters' do
      expect(client.app_id).to eq(app_id)
      expect(client.api_key).to eq(api_key)
    end

    it 'raises error when app_id is missing' do
      expect {
        MantleClient.new(app_id: nil, api_key: api_key)
      }.to raise_error(ArgumentError, 'MantleClient app_id is required')
    end

    it 'raises error when both api_key and customer_api_token are missing' do
      expect {
        MantleClient.new(app_id: app_id)
      }.to raise_error(ArgumentError, 'MantleClient one of apiKey or customerApiToken is required')
    end
  end

  describe '#mantle_request' do
    let(:mock_response) { double('response', body: '{"data": "test"}') }
    let(:mock_http) { instance_double(Net::HTTP) }
    let(:mock_uri) { URI.parse("#{api_url}/test") }
    
    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:request).and_return(mock_response)
    end

    it 'configures SSL for HTTPS URLs' do
      expect(mock_http).to receive(:use_ssl=).with(true)
      
      client.mantle_request(path: 'test')
    end

    it 'handles API errors gracefully' do
      error_response = double('response', body: '{"error": "Invalid request"}')
      allow(mock_http).to receive(:request).and_return(error_response)
      
      result = client.mantle_request(path: 'test')
      expect(result).to eq({ "error" => "Invalid request" })
    end

    it 'raises error when API request fails' do
      allow(mock_http).to receive(:request).and_raise(StandardError.new("Network error"))
      
      expect {
        client.mantle_request(path: 'test')
      }.to raise_error(StandardError, "Network error")
    end
  end

  describe '#identify' do
    let(:success_response) { { "customer" => { "id" => "cust_123" } } }
    
    before do
      allow(client).to receive(:mantle_request).and_return(success_response)
    end
    
    it 'sends identify request with correct parameters' do
      params = {
        platform_id: '123',
        myshopify_domain: 'test.myshopify.com',
        platform: 'shopify',
        access_token: 'token',
        name: 'Test User',
        email: 'test@example.com',
        custom_fields: { field: 'value' }
      }

      expect(client).to receive(:mantle_request).with(
        path: 'identify',
        method: 'POST',
        body: {
          platformId: '123',
          myshopifyDomain: 'test.myshopify.com',
          platform: 'shopify',
          accessToken: 'token',
          name: 'Test User',
          email: 'test@example.com',
          customFields: { field: 'value' }
        }
      ).and_return(success_response)

      result = client.identify(**params)
      expect(result).to eq(success_response)
    end

    it 'handles identify failure' do
      error_response = { "error" => "Invalid shop domain" }
      allow(client).to receive(:mantle_request).and_return(error_response)

      result = client.identify(
        platform_id: '123',
        myshopify_domain: 'invalid.myshopify.com',
        platform: 'shopify',
        access_token: 'token',
        name: 'Test User',
        email: 'test@example.com'
      )
      expect(result).to eq(error_response)
    end
  end

  describe '#get_customer' do
    it 'retrieves customer information' do
      customer_data = { 'id' => '123', 'name' => 'Test User' }
      expect(client).to receive(:mantle_request)
        .with(path: 'customer')
        .and_return({ 'customer' => customer_data })

      result = client.get_customer
      expect(result).to eq(customer_data)
    end
  end

  describe '#subscribe' do
    let(:success_response) { { "subscription" => { "id" => "sub_123" } } }
    
    before do
      allow(client).to receive(:mantle_request).and_return(success_response)
    end

    it 'handles successful subscription' do
      params = {
        plan_id: 'plan_123',
        discount_id: 'discount_123',
        return_url: 'https://example.com/return',
        billing_provider: 'stripe'
      }

      expect(client).to receive(:mantle_request).with(
        path: 'subscriptions',
        method: 'POST',
        body: {
          planId: 'plan_123',
          discountId: 'discount_123',
          returnUrl: 'https://example.com/return',
          billingProvider: 'stripe'
        }
      ).and_return(success_response)

      result = client.subscribe(**params)
      expect(result).to eq(success_response)
    end

    it 'handles subscription failure' do
      error_response = { "error" => "Invalid plan ID" }
      allow(client).to receive(:mantle_request).and_return(error_response)

      result = client.subscribe(
        plan_id: 'invalid_plan',
        discount_id: 'discount_123',
        return_url: 'https://example.com/return'
      )
      expect(result).to eq(error_response)
    end
  end

  describe '#send_usage_event' do
    it 'sends single usage event' do
      params = {
        event_name: 'test_event',
        customer_id: 'cust_123',
        properties: { amount: 100 }
      }

      expect(client).to receive(:mantle_request).with(
        path: 'usage_events',
        method: 'POST',
        body: {
          eventName: 'test_event',
          customerId: 'cust_123',
          properties: { amount: 100 }
        }
      )

      client.send_usage_event(**params)
    end

    it 'raises error when event_name is missing' do
      expect {
        client.send_usage_event(
          customer_id: 'cust_123',
          properties: { amount: 100 }
        )
      }.to raise_error(ArgumentError, /missing keyword: :?event_name/)
    end

    it 'raises error when event_name is nil' do
      expect {
        client.send_usage_event(
          event_name: nil,
          customer_id: 'cust_123',
          properties: { amount: 100 }
        )
      }.to raise_error(ArgumentError, 'event_name is required')
    end
  end

  describe '#send_usage_events' do
    it 'sends multiple usage events' do
      events = [
        { eventName: 'event1', customerId: 'cust_123' },
        { eventName: 'event2', customerId: 'cust_456' }
      ]

      expect(client).to receive(:mantle_request).with(
        path: 'usage_events',
        method: 'POST',
        body: { events: events }
      )

      client.send_usage_events(events: events)
    end

    it 'raises error when events parameter is missing' do
      expect {
        client.send_usage_events
      }.to raise_error(ArgumentError)
    end

    it 'raises error when events is nil' do
      expect {
        client.send_usage_events(events: nil)
      }.to raise_error(ArgumentError, 'events is required')
    end
  end

  describe '#get_invoices' do
    let(:success_response) { { "invoices" => [{ "id" => "inv_123" }] } }

    it 'retrieves invoices with default parameters' do
      expect(client).to receive(:mantle_request)
        .with(path: 'invoices?page=0&limit=10', method: 'GET')
        .and_return(success_response)

      result = client.get_invoices
      expect(result).to eq(success_response)
    end

    it 'retrieves invoices with custom parameters' do
      expect(client).to receive(:mantle_request)
        .with(path: 'invoices?page=1&limit=20&customerId=cust_123', method: 'GET')
        .and_return(success_response)

      result = client.get_invoices(page: 1, limit: 20, customer_id: 'cust_123')
      expect(result).to eq(success_response)
    end
  end

  describe '#usage_metric_report' do
    let(:success_response) { { "report" => [{ "date" => "2024-03-20", "value" => 100 }] } }

    it 'retrieves usage metric report with required parameters' do
      expect(client).to receive(:mantle_request)
        .with(path: 'usage_metric/metric_123/report?period=daily', method: 'GET')
        .and_return(success_response)

      result = client.usage_metric_report(id: 'metric_123')
      expect(result).to eq(success_response)
    end

    it 'retrieves usage metric report with all parameters' do
      expect(client).to receive(:mantle_request)
        .with(
          path: 'usage_metric/metric_123/report?period=monthly&startDate=2024-01-01&endDate=2024-03-20&customerId=cust_123',
          method: 'GET'
        )
        .and_return(success_response)

      result = client.usage_metric_report(
        id: 'metric_123',
        period: 'monthly',
        start_date: '2024-01-01',
        end_date: '2024-03-20',
        customer_id: 'cust_123'
      )
      expect(result).to eq(success_response)
    end

    it 'raises error with invalid period' do
      expect {
        client.usage_metric_report(id: 'metric_123', period: 'invalid')
      }.to raise_error(ArgumentError, 'period must be daily, weekly, monthly, or yearly')
    end

    it 'raises error when id is missing' do
      expect {
        client.usage_metric_report(period: 'daily')
      }.to raise_error(ArgumentError, 'id is required')
    end
  end
end
