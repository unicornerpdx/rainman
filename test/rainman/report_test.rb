require_relative '../test_helper'

class ReportTest < MiniTest::Unit::TestCase

  include Rack::Test::Methods

  def setup
    SQL.run 'DELETE FROM stats'
  end

  def app
    App
  end

  def content_type_json
    {
      'CONTENT_TYPE' => 'application/json'
    }
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

    post '/report', { date: '2013-12-01', precision: 'hour' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['date'][0]['type']

    post '/report', { date: '2013-12-01 11:22:33', precision: 'day' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['date'][0]['type']

    post '/report', { date: 3 }.to_json, content_type_json
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['date'][0]['type']
  end

  def test_report_accepts_valid_date
    post '/report', { date: '2013-12-01', precision: 'day' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['date']

    post '/report', { date: '2013-12-01 11:22:33', precision: 'hour' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['date']
  end

  def test_report_rejects_invalid_precision
    post '/report', { date: '2013-12-01', precision: 'foo' }
    response = JSON.parse last_response.body
    assert_equal 'invalid', response['error']['parameters']['precision'][0]['type']
  end

  def test_report_accepts_valid_precision
    post '/report', { date: '2013-12-01 13:00:00', precision: 'hour' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['precision']

    post '/report', { date: '2013-12-01 13:00:00', precision: 'day' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['precision']
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

  def test_report_removes_invalid_utf8_chars
    post '/report', { 
      client_id: 'client-9',
      date: '2014-01-01',
      key: 'name',
      value: "servi\xE7o",
      number: 1
    }
    response = JSON.parse last_response.body
    assert_equal 1, STATS.filter(client_id: 'client-9').count
  end

  def test_report_accepts_number_as_value
    post '/report', {
      client_id: 'client-9',
      date: '2014-01-01',
      key: 'id',
      value: 100,
      number: 1
    }.to_json, content_type_json
    response = JSON.parse last_response.body
    assert_equal 1, STATS.filter(client_id: 'client-9').count
  end

  def test_report_accepts_number_as_key
    post '/report', {
      client_id: 'client-9',
      date: '2014-01-01',
      key: 1000,
      value: 'foo',
      number: 1
    }.to_json, {
      'CONTENT_TYPE' => 'application/json'
    }
    response = JSON.parse last_response.body
    assert_equal 1, STATS.filter(client_id: 'client-9').count
  end

  def test_report_accepts_group_id
    post '/report', { group_id: '10000' }
    response = JSON.parse last_response.body
    assert_nil response['error']['parameters']['group_id']
  end

  def test_report_without_group
    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 10
    }

    assert_equal 1, STATS.filter(client_id: 'client-1').count
    assert_equal 10, STATS.filter(client_id: 'client-1').first[:num]
  end

  def test_report_segments_data_by_group
    post '/report', { 
      group_id: 'group-a',
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 1
    }

    post '/report', { 
      group_id: 'group-b',
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 1
    }

    group_a = STATS.filter(group_id: 'group-a').first[:num]
    group_b = STATS.filter(group_id: 'group-b').first[:num]

    assert_equal 1, group_a
    assert_equal 1, group_b
  end

  def test_report_segments_data_by_client
    post '/report', { 
      group_id: 'group-a',
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 1
    }

    post '/report', { 
      group_id: 'group-a',
      client_id: 'client-2',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 1
    }

    assert_equal 2, STATS.filter(group_id: 'group-a').count # should insert as two separate rows
    assert_equal 1, STATS.filter(group_id: 'group-a', client_id: 'client-1').first[:num]
    assert_equal 1, STATS.filter(group_id: 'group-a', client_id: 'client-2').first[:num]
  end

  def test_report_segments_data_by_date
    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 5
    }

    post '/report', {
      client_id: 'client-1',
      date: '2014-01-02',
      key: 'version',
      value: '1.0',
      number: 6
    }

    assert_equal 2, STATS.filter(client_id: 'client-1').count
    assert_equal 5, STATS.filter(client_id: 'client-1', date: '2014-01-01').first[:num]
    assert_equal 6, STATS.filter(client_id: 'client-1', date: '2014-01-02').first[:num]
  end

  def test_report_segments_data_by_hour
    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01 10:20:00',
      precision: 'hour',
      key: 'version',
      value: '1.0',
      number: 5
    }

    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01 11:40:00',
      precision: 'hour',
      key: 'version',
      value: '1.0',
      number: 6
    }

    assert_equal 2, STATS.filter(client_id: 'client-1').count
    assert_equal 0, STATS.filter(client_id: 'client-1', date: '2014-01-01', hour: 9).count
    assert_equal 5, STATS.filter(client_id: 'client-1', date: '2014-01-01', hour: 10).first[:num]
    assert_equal 6, STATS.filter(client_id: 'client-1', date: '2014-01-01', hour: 11).first[:num]
    assert_equal 2, STATS.filter(client_id: 'client-1', date: '2014-01-01').count
  end

  def test_report_segments_data_by_value
    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 5
    }

    post '/report', {
      client_id: 'client-1',
      date: '2014-01-02',
      key: 'version',
      value: '1.1',
      number: 6
    }

    assert_equal 2, STATS.filter(client_id: 'client-1').count
    assert_equal 5, STATS.filter(client_id: 'client-1', value: '1.0').first[:num]
    assert_equal 6, STATS.filter(client_id: 'client-1', value: '1.1').first[:num]
  end

  def test_report_increments_num
    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 2
    }

    post '/report', {
      client_id: 'client-1',
      date: '2014-01-01',
      key: 'version',
      value: '1.0',
      number: 3
    }

    assert_equal 5, STATS.filter(client_id: 'client-1', date: '2014-01-01').first[:num]
  end

end
