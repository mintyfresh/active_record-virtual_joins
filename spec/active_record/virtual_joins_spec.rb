# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveRecord::VirtualJoins do
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }

  describe '.virtual_joins' do
    subject(:relation) { User.virtual_joins(:id, values, score: :integer, note: :string) }

    let(:values) { [{ id: user.id, score: 10, note: 'first' }] }

    it 'selects the values onto the matching records' do
      expect(relation.find(user.id)).to have_attributes(score: 10, note: 'first')
    end

    it 'keeps records without matching values, with null values' do
      expect(relation.find(other_user.id)).to have_attributes(score: nil, note: nil)
    end

    it 'selects the columns of the records' do
      expect(relation.find(user.id)).to have_attributes(id: user.id, name: user.name)
    end

    it 'does not select the join column of the virtual table' do
      expect(relation).not_to include_sql('users_id_json.id,')
    end

    it 'names the virtual table after the table and join column' do
      expect(relation).to include_sql('ON users.id = users_id_json.id')
    end

    it 'can be filtered and ordered by the values' do
      values << { id: other_user.id, score: 20 }

      expect(relation.where('users_id_json.score > 5').order('users_id_json.score DESC'))
        .to eq([other_user, user])
    end

    context 'with keys that are not columns of the virtual table' do
      let(:values) { [{ id: user.id, score: 10, unknown: 'ignored' }] }

      it 'ignores the keys, and leaves missing columns null', :aggregate_failures do
        record = relation.find(user.id)

        expect(record).to have_attributes(score: 10, note: nil)
        expect(record).not_to respond_to(:unknown)
      end
    end

    context 'with string keys' do
      subject(:relation) { User.virtual_joins('id', values, 'score' => :integer) }

      let(:values) { [{ 'id' => user.id, 'score' => 10 }] }

      it 'selects the values onto the matching records' do
        expect(relation.find(user.id).score).to eq(10)
      end
    end

    context 'with no values' do
      let(:values) { [] }

      it 'keeps every record, with null values' do
        expect(relation.map(&:score)).to eq([nil, nil])
      end
    end

    context 'with a table name' do
      subject(:relation) { User.virtual_joins(:id, values, join_table_name: :scores, score: :integer) }

      it 'names the virtual table', :aggregate_failures do
        expect(relation).to include_sql('ON users.id = scores.id')
        expect(relation.find(user.id).score).to eq(10)
      end
    end

    context 'with an SQL type' do
      subject(:relation) { User.virtual_joins(:id, values, score: 'integer') }

      it 'uses the type as it is' do
        expect(relation.find(user.id).score).to eq(10)
      end
    end

    context 'with a join column other than the primary key' do
      subject(:relation) { Post.virtual_joins(:slug, [{ slug: post.slug, views: 3 }], views: :integer) }

      let(:post) { create(:post) }

      it 'matches records by the join column' do
        expect(relation.find(post.id).views).to eq(3)
      end
    end

    context 'with a join column that is not a column of the model' do
      it 'requires the type of the join column' do
        expect { User.virtual_joins(:unknown, values, score: :integer) }
          .to raise_error(ArgumentError, /type of the join column `unknown` must be given/)
      end
    end

    context 'with typed values',
            skip: ActiveRecord::Base.connection_db_config.adapter == 'sqlite3' &&
                  "SQLite doesn't convert JSON values to the types of the columns" do
      subject(:relation) { User.virtual_joins(:id, values, amount: 'decimal(10, 2)', active: :boolean, at: :datetime) }

      let(:values) { [{ id: user.id, amount: '12.50', active: true, at: Time.zone.parse('2026-11-03 12:30:00') }] }

      it 'converts the values to the types of the columns' do
        expect(relation.find(user.id)).to have_attributes(
          amount: BigDecimal('12.5'),
          active: be(true).or(be(1)),
          at: Time.zone.parse('2026-11-03 12:30:00')
        )
      end
    end
  end

  describe 'relations' do
    it 'keeps the conditions of the relation' do
      relation = User.where(id: user.id).virtual_joins(:id, [{ id: user.id, score: 10 }], score: :integer)

      expect(relation.map(&:score)).to eq([10])
    end

    it 'keeps the projection of the relation', :aggregate_failures do
      record = User.select(:id).virtual_joins(:id, [{ id: user.id, score: 10 }], score: :integer).find(user.id)

      expect(record.attributes).to eq('id' => user.id, 'score' => 10)
    end

    it 'joins values to association relations' do
      post = create(:post, user:)
      relation = user.posts.virtual_joins(:slug, [{ slug: post.slug, views: 3 }], views: :integer)

      expect(relation.map(&:views)).to eq([3])
    end
  end

  describe 'models that are not extended' do
    let(:model) do
      Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
        self.table_name = 'users'
      end
    end

    it 'does not provide virtual_joins' do
      expect(model).not_to respond_to(:virtual_joins)
    end
  end
end
