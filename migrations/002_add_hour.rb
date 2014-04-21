Sequel.migration do
  up do
    add_column :stats, :hour, Integer
    alter_table(:stats) do
      add_index [:group_id, :client_id, :date, :hour, :key]
      add_index [:client_id, :date, :hour, :key]
      add_index [:date, :hour, :key]
      drop_index [:group_id, :client_id, :date, :key]
      drop_index [:client_id, :date, :key]
      drop_index [:date, :key]
    end
  end
  down do
    alter_table(:stats) do
      drop_index [:group_id, :client_id, :date, :hour, :key]
      drop_index [:client_id, :date, :hour, :key]
      drop_index [:date, :hour, :key]
      add_index [:group_id, :client_id, :date, :key]
      add_index [:client_id, :date, :key]
      add_index [:date, :key]
    end
    drop_column :stats, :hour
  end
end