class App < Jsonatra::Base

  ds = SQL["UPDATE stats SET num=num + ?::int
            WHERE group_id=?::text AND client_id=?::text AND date=?::timestamp AND key=?::text AND value=?::text", :$number, :$group, :$client, :$date, :$key, :$value]
  ds.prepare(:update, :update_stat)

  ds = SQL["UPDATE stats SET num=num + ?::int
            WHERE group_id=?::text AND client_id=?::text AND date=?::timestamp AND hour=?::int AND key=?::text AND value=?::text", :$number, :$group, :$client, :$date, :$hour, :$key, :$value]
  ds.prepare(:update, :update_stat_hour)

  ds = SQL["INSERT INTO stats (group_id, client_id, date, key, value, num)
            SELECT ?::text, ?::text, ?::timestamp, ?::text, ?::text, ?::int
            WHERE NOT EXISTS (SELECT 1 FROM stats
                              WHERE group_id=?::text AND client_id=?::text AND date=?::timestamp AND key=?::text AND value=?::text)", :$group, :$client, :$date, :$key, :$value, :$number, :$group, :$client, :$date, :$key, :$value]
  ds.prepare(:insert, :insert_stat)

  ds = SQL["INSERT INTO stats (group_id, client_id, date, hour, key, value, num)
            SELECT ?::text, ?::text, ?::timestamp, ?::int, ?::text, ?::text, ?::int
            WHERE NOT EXISTS (SELECT 1 FROM stats
                              WHERE group_id=?::text AND client_id=?::text AND date=?::timestamp AND hour=?::int AND key=?::text AND value=?::text)", :$group, :$client, :$date, :$hour, :$key, :$value, :$number, :$group, :$client, :$date, :$hour, :$key, :$value]
  ds.prepare(:insert, :insert_stat_hour)

  configure do
    set :arrayified_params, [:keys]
  end

  get '/' do
    {
      hello: 'world'
    }
  end

  post '/report' do
    param_error :date, 'missing', 'date parameter required' if params[:date].blank?
    # group_id is allowed to be null
    param_error :client_id, 'missing', 'client_id parameter required' if params[:client_id].blank?
    param_error :key, 'missing', 'key parameter required' if params[:key].blank?
    param_error :value, 'missing', 'value parameter required' if params[:value].blank?
    param_error :number, 'missing', 'number parameter required' if params[:number].blank?
    param_error :number, 'invalid', 'number must be an integer' unless params[:number] && params[:number].to_s.match(/^[0-9]+$/)

    params[:precision] = 'day' if params[:precision].blank?
    param_error :precision, 'invalid', 'precision must be day or hour' unless ['day','hour'].include? params[:precision]

    # If precision is "hour" then the date must be a full timestamp
    if params[:precision] == 'day'
      param_error :date, 'invalid', 'date parameter should look like YYYY-MM-DD for day precision' unless params[:date] && params[:date].match(/^\d{4}-\d{2}-\d{2}$/)
    else
      param_error :date, 'invalid', 'date parameter should look like "YYYY-MM-DD HH:mm:ss" for hour precision' unless params[:date] && params[:date].match(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/)
    end

    halt if response.error?

    params[:value] = params[:value].scrub

    if params[:precision] == 'day'
      SQL.call :update_stat, :number => params[:number], :group => (params[:group_id] || ''), :client => params[:client_id], :date => params[:date], :key => params[:key], :value => params[:value]
      SQL.call :insert_stat, :number => params[:number], :group => (params[:group_id] || ''), :client => params[:client_id], :date => params[:date], :key => params[:key], :value => params[:value]
    else
      date = params[:date].match(/^(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}:\d{2}$/)[1]
      hour = params[:date].match(/^\d{4}-\d{2}-\d{2} (\d{2}):\d{2}:\d{2}$/)[1]
      SQL.call :update_stat_hour, :number => params[:number], :group => (params[:group_id] || ''), :client => params[:client_id], :date => date, :hour => hour, :key => params[:key], :value => params[:value]
      SQL.call :insert_stat_hour, :number => params[:number], :group => (params[:group_id] || ''), :client => params[:client_id], :date => date, :hour => hour, :key => params[:key], :value => params[:value]
    end

    {
      result: "ok"
    }
  end

  get '/query' do
    param_error :keys, 'missing', 'keys parameter required' if params[:keys] == nil || params[:keys].size == 0
    param_error :value, 'invalid', 'value parameter cannot be specified when requesting multiple keys' if (params[:value] || !params[:value].blank?) and params[:keys].size > 1
    param_error :from, 'invalid', 'date parameter should look like YYYY-MM-DD' if params[:from] && !params[:from].match(/^\d{4}-\d{2}-\d{2}$/)
    param_error :to, 'invalid', 'date parameter should look like YYYY-MM-DD' if params[:to] && !params[:to].match(/^\d{4}-\d{2}-\d{2}$/)

    # jsonatra doesn't split query string parameters into an array right now
    # https://github.com/esripdx/jsonatra/issues/3
    if String === params[:value]
      params[:value] = params[:value].split ','
    end

    if params[:format] == 'panic'
      param_error :keys, 'invalid', 'only one key can be specified when format=panic' if params[:keys].size > 1
    end

    halt if response.error?

    stats = STATS.select_group(:date, :key, :value)
    stats.select_append!{sum(num).as(num)}

    stats.filter!(key: params[:keys])

    # filter by optional arguments
    stats.filter!(group_id: params[:group_id]) if params[:group_id]
    stats.filter!(client_id: params[:client_id]) if params[:client_id]
    stats.filter!(value: params[:value]) if params[:value]    
    stats.filter!("date >= ?", params[:from]) if params[:from]
    stats.filter!("date <= ?", params[:to]) if params[:to]

    stats.order_by!(:date, :key, :value)

    if params[:format] == 'panic'
      # JSON format for Panic StatusBoard

      # Collect all the dates
      dates = stats.map{|s| s[:date]}.uniq.sort
      # Set the values for each date for each key to 0, to ensure each key has values for each date

      datapoints = {}
      dates.each do |d| 
        datapoints[d.strftime('%b %-d')] = {
          :title => d.strftime('%b %-d'),
          :value => 0
        }
      end

      results = {}
      stats.each do |s|
        value = s[:value]
        # Set up the initial data
        if results[value].nil?
          results[value] = {
            :title => value,
            :datapoints => datapoints.clone
          } 
        end
        results[value][:datapoints][s[:date].strftime('%b %-d')] = {
          :title => s[:date].strftime('%b %-d'),
          :value => s[:num]
        }
      end

      sequences = results.values

      # Remove the date key from the datapoints objects
      sequences.each do |s|
        s[:datapoints] = s[:datapoints].values
      end

      {
        graph: {
          title: (params[:title] || params[:keys][0].split('_').map{|w| w.capitalize}.join(' ')),
          refreshEveryNSeconds: 120,
          type: "bar",
          datasequences: sequences
        }
      }
    else
      # Standard JSON format

      results = {}
      stats.each{ |s|
        key = s[:key]
        date = s[:date]
        results[date] = results[date] || {}
        results[date][key] = results[date][key] || {}
        results[date][key][s[:value]] = s[:num]
        results[date][:date] = date.strftime '%Y-%m-%d'
      }

      { 
        data: results.values 
      }
    end
  end

end
