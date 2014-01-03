class App < Jsonatra::Base

  puts "Preparing SQL statements"
  DB.prepare 'updatestat', "UPDATE stats SET num=num+$1::int
                        WHERE group_id=$2::text AND client_id=$3::text AND date=$4::timestamp AND key=$5::text AND value=$6::text"
  DB.prepare 'insertstat', "INSERT INTO stats (group_id, client_id, date, key, value, num)
              SELECT $2::text, $3::text, $4::timestamp, $5::text, $6::text, $1::int
              WHERE NOT EXISTS (SELECT 1 FROM stats
                WHERE group_id=$2::text AND client_id=$3::text AND date=$4::timestamp AND key=$5::text AND value=$6::text)"

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
    param_error :date, 'invalid', 'date parameter should look like YYYY-MM-DD' unless params[:date] && params[:date].match(/^\d{4}-\d{2}-\d{2}$/)
    # group_id is allowed to be null
    param_error :client_id, 'missing', 'client_id parameter required' if params[:client_id].blank?
    param_error :key, 'missing', 'key parameter required' if params[:key].blank?
    param_error :value, 'missing', 'value parameter required' if params[:value].blank?
    param_error :number, 'missing', 'number parameter required' if params[:number].blank?
    param_error :number, 'invalid', 'number must be an integer' unless params[:number] && params[:number].to_s.match(/^[0-9]+$/)

    halt if response.error?

    DB.exec 'BEGIN'
    DB.exec_prepared 'updatestat', [params[:number], params[:group_id] || '', params[:client_id], params[:date], params[:key], params[:value]]
    DB.exec_prepared 'insertstat', [params[:number], params[:group_id] || '', params[:client_id], params[:date], params[:key], params[:value]]
    DB.exec 'COMMIT'

    {
      result: "ok"
    }
  end

  get '/query' do
    param_error :keys, 'missing', 'keys parameter required' if params[:keys] == nil || params[:keys].size == 0
    param_error :value, 'invalid', 'value parameter cannot be specified when requesting multiple keys' if !params[:value].blank? and params[:keys].size > 1
    param_error :from, 'invalid', 'date parameter should look like YYYY-MM-DD' if params[:from] && !params[:from].match(/^\d{4}-\d{2}-\d{2}$/)
    param_error :to, 'invalid', 'date parameter should look like YYYY-MM-DD' if params[:to] && !params[:to].match(/^\d{4}-\d{2}-\d{2}$/)

    halt if response.error?

    stats = STATS.filter(key: params[:keys])

    # filter by optional arguments
    stats.filter!(group_id: params[:group_id]) if params[:group_id]
    stats.filter!(client_id: params[:client_id]) if params[:client_id]
    stats.filter!(value: params[:value]) if params[:value]    
    stats.filter!("date >= ?", params[:from]) if params[:from]
    stats.filter!("date <= ?", params[:to]) if params[:to]

    stats.order_by!(:date, :key, :value)

    # construct response object
    results = {}
    stats.each{ |s|
      key = s[:key]
      date = s[:date]
      results[date] = results[date] || {}
      results[date][key] = results[date][key] || {}
      results[date][key][s[:value]] = s[:num]
      results[date][:date] = date.strftime '%Y-%m-%d'
    }

    results.values.to_json
  end

end
