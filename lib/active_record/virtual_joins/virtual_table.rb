# typed: true
# frozen_string_literal: true

module ActiveRecord
  module VirtualJoins
    # A table of values decoded from JSON by the database, with the SQL to join it to a model's table:
    # * PostgreSQL - `json_to_recordset`
    # * MySQL - `JSON_TABLE`
    # * SQLite - `json_each` (which doesn't convert the values to the types of the columns)
    class VirtualTable
      #: String
      attr_reader :name

      #: (
      #|   singleton(ActiveRecord::Base) model,
      #|   Symbol | String name,
      #|   Symbol | String join_column_name,
      #|   Hash[Symbol | String, Symbol | String] column_types
      #| ) -> void
      def initialize(model, name, join_column_name, column_types)
        @model = model
        @name = name.to_s
        @join_column_name = join_column_name.to_s
        @column_types = column_types.transform_keys(&:to_s)
        @column_types[@join_column_name] ||= join_column_type
      end

      # Joins the virtual table to the model's table, by the join column.
      #
      #: (Enumerable[Hash[Symbol | String, untyped]] values) -> String
      def join_sql(values)
        @model.with_connection do |connection|
          source = source_sql(connection)
          condition = "#{@model.quoted_table_name}.#{connection.quote_column_name(@join_column_name)} = " \
                      "#{qualified_column_name(connection, @join_column_name)}"

          @model.sanitize_sql_array(
            ["LEFT OUTER JOIN #{source} ON #{condition}", ActiveSupport::JSON.encode(values.to_a)]
          )
        end
      end

      # The columns of the virtual table, other than the join column (which is the same as the model's).
      #
      #: -> Array[Arel::Nodes::SqlLiteral]
      def select_values
        @model.with_connection do |connection|
          @column_types.keys.excluding(@join_column_name).map do |column_name|
            Arel.sql(qualified_column_name(connection, column_name))
          end
        end
      end

    private

      #: -> String
      def join_column_type
        column = @model.columns_hash[@join_column_name]
        return column.sql_type if column

        raise ArgumentError, "The type of the join column `#{@join_column_name}` must be given, " \
                             "since it isn't a column of `#{@model.name}`."
      end

      # The table, which decodes the values from a JSON array of objects (given as a bind parameter).
      #
      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def source_sql(connection)
        case connection.adapter_name
        when /postgres/i then postgresql_source_sql(connection)
        when /mysql|trilogy/i then mysql_source_sql(connection)
        when /sqlite/i then sqlite_source_sql(connection)
        else
          raise NotImplementedError, "virtual_joins isn't supported by the #{connection.adapter_name} adapter."
        end
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def postgresql_source_sql(connection)
        columns = @column_types.map do |column_name, type|
          "#{connection.quote_column_name(column_name)} #{sql_type(connection, type)}"
        end

        "json_to_recordset(?::json) AS #{connection.quote_table_name(name)}(#{columns.join(', ')})"
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def mysql_source_sql(connection)
        columns = @column_types.map do |column_name, type|
          "#{connection.quote_column_name(column_name)} #{sql_type(connection, type)} " \
            "PATH #{connection.quote(json_path(column_name))}"
        end

        "JSON_TABLE(?, '$[*]' COLUMNS(#{columns.join(', ')})) AS #{connection.quote_table_name(name)}"
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def sqlite_source_sql(connection)
        columns = @column_types.keys.map do |column_name|
          "json_extract(value, #{connection.quote(json_path(column_name))}) " \
            "AS #{connection.quote_column_name(column_name)}"
        end

        "(SELECT #{columns.join(', ')} FROM json_each(?)) AS #{connection.quote_table_name(name)}"
      end

      # ActiveRecord types are converted to the database's types (eg. `:string` to `character varying`),
      # while SQL types are used as they are.
      #
      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection, Symbol | String type) -> String
      def sql_type(connection, type)
        type.is_a?(Symbol) ? connection.type_to_sql(type) : type
      end

      # A path to a key of a JSON object (which is quoted, so that keys aren't parsed as paths).
      #
      #: (String column_name) -> String
      def json_path(column_name)
        "$.#{column_name.to_json}"
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection, String column_name) -> String
      def qualified_column_name(connection, column_name)
        "#{connection.quote_table_name(name)}.#{connection.quote_column_name(column_name)}"
      end
    end
  end
end
