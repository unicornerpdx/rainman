Sequel.migration do
  up do
    create_table(:stats) do
      primary_key :id
      String :group_id
      String :client_id
      DateTime :date
      String :key
      String :value
      Integer :num
      index [:group_id, :client_id, :date, :key]
      index [:client_id, :date, :key]
      index [:date, :key]
      index [:key]
    end
  end

  down do
    drop_table(:stats)
  end
end