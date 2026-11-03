# frozen_string_literal: true

require 'rails_helper'
require 'tapioca/dsl/compilers/active_record_virtual_joins'

RSpec.describe Tapioca::Dsl::Compilers::ActiveRecordVirtualJoins do
  subject(:rbi) do
    Tapioca::Dsl::Pipeline.new(requested_constants: [User], requested_compilers:, number_of_workers: 1)
      .run { |_constant, file| Tapioca::DEFAULT_RBI_FORMATTER.print_file(file) }
      .first
  end

  let(:requested_compilers) { [Tapioca::Dsl::Compilers::ActiveRecordRelations, described_class] }
  let(:parameter_types) do
    'join_column_name: T.any(Symbol, String), ' \
      'join_values: T::Enumerable[T::Hash[T.any(Symbol, String), T.untyped]], ' \
      'join_table_name: T.any(Symbol, String), ' \
      'join_value_types: T.any(Symbol, String)'
  end

  it 'adds virtual_joins to the relation methods' do
    expect(rbi.scan(/^ *def virtual_joins\(.*$/).map(&:strip)).to eq(
      [
        'def virtual_joins(join_column_name, join_values, ' \
        'join_table_name: "#{table_name}_#{join_column_name}_json", **join_value_types); end', # rubocop:disable Lint/InterpolationCheck
      ] * 2
    )
  end

  it 'types virtual_joins by the relation it returns', :aggregate_failures do
    expect(rbi).to include("sig { params(#{parameter_types}).returns(PrivateRelation) }")
    expect(rbi).to include("sig { params(#{parameter_types}).returns(PrivateAssociationRelation) }")
  end

  it 'adds the methods to the generated relation modules', :aggregate_failures do
    expect(rbi).to match(/module GeneratedRelationMethods\b(?:(?!^  end).)*def virtual_joins/m)
    expect(rbi).to match(/module GeneratedAssociationRelationMethods\b(?:(?!^  end).)*def virtual_joins/m)
  end

  context 'when the ActiveRecordRelations compiler is not enabled' do
    let(:requested_compilers) { [described_class] }

    it 'generates nothing' do
      expect(rbi).to be_nil
    end
  end
end
