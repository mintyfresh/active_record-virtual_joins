# typed: true
# frozen_string_literal: true

require 'active_record'
require 'active_record/virtual_joins/version'

module ActiveRecord
  # Joins lists of hashes to the records of a model and its subclasses, as virtual tables:
  #
  #   class ApplicationRecord < ActiveRecord::Base
  #     extend ActiveRecord::VirtualJoins
  #   end
  #
  #   users = User.virtual_joins(:id, [{ id: 1, score: 10 }, { id: 2, score: 20 }], score: :integer)
  #   users.find(1).score # => 10
  module VirtualJoins
    autoload :VirtualTable, 'active_record/virtual_joins/virtual_table'

    # Left-joins a list of hashes as a virtual table, matched to records by the join column,
    # and selects the other columns of the virtual table onto the records.
    #
    # The columns of the virtual table are given with their types, as ActiveRecord types (eg. `:integer`)
    # or SQL types (eg. `'numeric(10, 2)'`). The type of the join column defaults to that of the model's column.
    # Keys of the hashes that aren't columns of the virtual table are ignored, and missing keys are null.
    #
    # The records' own columns are selected, unless the relation already selects other columns.
    #
    #: (
    #|   Symbol | String join_column_name,
    #|   Enumerable[Hash[Symbol | String, untyped]] join_values,
    #|   ?join_table_name: Symbol | String,
    #|   **Symbol | String join_value_types
    #| ) -> ActiveRecord::Relation
    def virtual_joins(
      join_column_name,
      join_values,
      join_table_name: "#{table_name}_#{join_column_name}_json",
      **join_value_types
    )
      virtual_table = VirtualTable.new(self, join_table_name, join_column_name, join_value_types)

      relation = all.joins(virtual_table.join_sql(join_values))
      relation = relation.select(arel_table[Arel.star]) if relation.select_values.empty?

      select_values = virtual_table.select_values
      select_values.empty? ? relation : relation.select(*select_values)
    end
  end
end
