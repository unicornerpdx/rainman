require_relative '../test_helper'

class AppTest < MiniTest::Unit::TestCase

  include Rack::Test::Methods

  def app
    App
  end

  def test_hello_world
    get '/' 
    assert last_response.ok?
    assert_equal ({hello: 'world'}).to_json, last_response.body
  end

  def test_report_empty_parameters
    post '/report'
    assert last_response.ok?
    response = JSON.parse last_response.body
    assert_equal 'invalid_input', response['error']['type']

    required_params = ['date','client_id','key','value','number']

    parameters = response['error']['parameters'].keys
    required_params.each do |param|
      assert_includes response['error']['parameters'].keys, param
      parameters.delete param
    end
    assert_equal [], parameters
  end

  def test_report_rejects_invalid_date
    post '/report', { date: 'FOO' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['date'][0]['type']

    post '/report', { date: '20131201' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['date'][0]['type']
  end

  def test_report_accepts_valid_date
    post '/report', { date: '2013-12-01' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['date']
  end

  def test_report_accepts_valid_client_id
    post '/report', { client_id: '100000' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['client_id']
  end

  def test_report_accepts_valid_key
    post '/report', { key: 'version' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['key']
  end

  def test_report_accepts_valid_value
    post '/report', { value: '1.0' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['value']
  end

  def test_report_accepts_valid_number
    post '/report', { number: 100 }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['number']
  end

  def test_report_rejects_invalid_number
    post '/report', { number: 'FOO' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['number'][0]['type']
    assert_equal 'number must be an integer', response['error']['parameters']['number'][0]['message']
  end

end
