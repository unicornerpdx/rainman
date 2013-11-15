class App < Jsonatra::Base

  puts "Preparing SQL statements"
  DB.prepare 'updatestat', "UPDATE stats SET num=num+$1::int 
                        WHERE client_id=$2::text AND date=$3::timestamp AND key=$4::text AND value=$5::text"
  DB.prepare 'insertstat', "INSERT INTO stats (client_id, date, key, value, num)
              SELECT $2::text, $3::timestamp, $4::text, $5::text, $1::int
              WHERE NOT EXISTS (SELECT 1 FROM stats 
                WHERE client_id=$2::text AND date=$3::timestamp AND key=$4::text AND value=$5::text)"

  get '/' do
    {
      hello: 'world'
    }
  end

  post '/report' do
    param_error :date, 'missing', 'date parameter required' unless params[:date]
    param_error :date, 'invalid', 'date parameter should look like YYYYMMDD' unless params[:date] && params[:date].match(/^\d{8}$/)
    param_error :client_id, 'missing', 'client_id parameter required' unless params[:client_id]
    param_error :key, 'missing', 'key parameter required' if params[:key] == nil or params[:key].empty?
    param_error :value, 'missing', 'value parameter required' if params[:value] == nil or params[:value].empty?
    param_error :number, 'missing', 'number parameter required' if params[:number] == nil or params[:number].empty?
    param_error :number, 'invalid', 'number must be an integer' unless params[:number] && params[:number].match(/^[0-9]+$/)

    DB.exec 'BEGIN'
    DB.exec_prepared 'updatestat', [params[:number], params[:client_id], params[:date], params[:key], params[:value]]
    DB.exec_prepared 'insertstat', [params[:number], params[:client_id], params[:date], params[:key], params[:value]]
    DB.exec 'COMMIT'

    {
      result: "ok"
    }
  end

end
