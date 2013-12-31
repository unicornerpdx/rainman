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

end
