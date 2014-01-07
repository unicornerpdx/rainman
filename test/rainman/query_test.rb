require_relative '../test_helper'

class QueryTest < MiniTest::Unit::TestCase

  include Rack::Test::Methods

  def app
    App
  end

  def setup
    DB.exec 'DELETE FROM stats'

    # Insert a bunch of test data to query

    (0..30).each do |i|
      post '/report', {
        group_id: 'group-a',
        client_id: 'client-1',
        date: (DateTime.parse('2014-01-01')+i).strftime('%Y-%m-%d'),
        key: 'version',
        value: '1.0',
        number: i
      }
    end

    ['b','c','d','e'].each do |g|
      (1..4).each do |c|
        post '/report', {
          group_id: "group-#{g}",
          client_id: "client-#{c}",
          date: '2014-01-01',
          key: 'name',
          value: 'test',
          number: 5
        }
        post '/report', {
          group_id: "group-#{g}",
          client_id: "client-#{c}",
          date: '2014-01-01',
          key: 'version',
          value: '1.0',
          number: 2
        }
        post '/report', {
          group_id: "group-#{g}",
          client_id: "client-#{c}",
          date: '2014-01-02',
          key: 'version',
          value: '1.0',
          number: 4
        }
        post '/report', {
          group_id: "group-#{g}",
          client_id: "client-#{c}",
          date: '2014-01-01',
          key: 'version',
          value: '1.1',
          number: 3
        }
        post '/report', {
          group_id: "group-#{g}",
          client_id: "client-#{c}",
          date: '2014-01-02',
          key: 'version',
          value: '1.1',
          number: 5
        }
      end
    end

    (1..4).each do |i|
      post '/report', {
        group_id: "group-f",
        client_id: "client-5",
        date: '2014-01-01',
        key: 'version',
        value: '1.0',
        number: 5
      }
    end

  end

  def test_query_empty_parameters
    post '/query'

    assert last_response.ok?
    response = JSON.parse last_response.body
    assert_equal 'invalid_input', response['error']['type']

    required_params = ['keys']

    parameters = response['error']['parameters'].keys
    required_params.each do |param|
      assert_includes response['error']['parameters'].keys, param
      parameters.delete param
    end
    assert_equal [], parameters
  end

  def test_query_rejects_invalid_from_date
    post '/query', { from: 'FOO' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['from'][0]['type']

    post '/query', { from: '20131201' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['from'][0]['type']
  end

  def test_query_rejects_invalid_to_date
    post '/query', { to: 'FOO' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['to'][0]['type']

    post '/query', { to: '20131201' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['to'][0]['type']
  end

  def test_query_rejects_value_with_multiple_keys
    post '/query', { keys: 'device_os,device_version', value: '1.0' }
    response = JSON.parse last_response.body
    assert_equal 'invalid_input', response['error']['type']
    assert_equal 'invalid', response['error']['parameters']['value'][0]['type']
  end

  def test_query_by_group_and_key
    post '/query', { group_id: 'group-a', keys: 'version' }
    response = JSON.parse last_response.body
    assert_equal 31, response['data'].length
    assert_equal 0, response['data'][0]['version']['1.0']
    assert_equal 30, response['data'][30]['version']['1.0']
  end

  def test_query_by_client_and_key
    post '/query', { client_id: 'client-2', keys: 'version' }
    response = JSON.parse last_response.body
    assert_equal 2, response['data'].length
    assert_equal '2014-01-01', response['data'][0]['date']
    assert_equal 2, response['data'][0]['version']['1.0']
    assert_equal 3, response['data'][0]['version']['1.1']
    assert_equal 4, response['data'][1]['version']['1.0']
    assert_equal 5, response['data'][1]['version']['1.1']
  end

  def test_query_of_summed_values
    post '/query', { client_id: 'client-5', keys: 'version' }
    response = JSON.parse last_response.body
    assert_equal 1, response['data'].length
    assert_equal 20, response['data'][0]['version']['1.0']
  end

end
