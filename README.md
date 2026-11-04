# ActiveRecord::VirtualJoins

Joins a list of Ruby hashes to the records of an ActiveRecord relation, as a virtual table.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record-virtual_joins'
```

And then execute:

```bash
$ bundle
```

Then extend your models with `ActiveRecord::VirtualJoins` (typically in `ApplicationRecord`, so all models get it):

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  extend ActiveRecord::VirtualJoins
end
```

## Usage

`virtual_joins` takes the column to join by, the list of hashes, and the types of the other columns.
The values are left-joined to the records by the join column, and selected onto them:

```ruby
scores = [{ id: 1, score: 10 }, { id: 2, score: 20 }]

users = User.virtual_joins(:id, scores, score: :integer)
# SELECT "users".*, "users_id_json"."score" FROM "users"
# LEFT OUTER JOIN json_to_recordset('[{"id":1,"score":10},{"id":2,"score":20}]'::json)
#   AS "users_id_json"("score" integer, "id" bigint)
#   ON "users"."id" = "users_id_json"."id"

users.find(1).score # => 10
users.find(3).score # => nil
```

Records without matching values are kept, with null values.
Keys of the hashes that aren't columns of the virtual table are ignored, and missing keys are null.

The values can be used in the rest of the query, by the name of the virtual table
(which defaults to the table and join column, eg. `users_id_json`):

```ruby
User.virtual_joins(:id, scores, score: :integer).where('users_id_json.score > 15').order('users_id_json.score')

User.virtual_joins(:id, scores, join_table_name: :scores, score: :integer).order('scores.score')
```

It can be called on any relation (including associations), and keeps the relation's conditions and projection:

```ruby
user.posts.where(published: true).virtual_joins(:slug, views, views: :integer)
User.select(:id).virtual_joins(:id, scores, score: :integer) # selects only users.id and the score
```

### Types

Types can be given as ActiveRecord types (eg. `:integer`, `:string`), which are converted to the database's types,
or as SQL types (eg. `'decimal(10, 2)'`), which are used as they are.
The type of the join column defaults to the type of the model's column, but can be given like any other column.

Note that `:decimal` uses the database's default precision, which is a scale of 0 on MySQL
(so use an SQL type like `'decimal(10, 2)'` for fractional values).

### Databases

PostgreSQL (`json_to_recordset`), MySQL (`JSON_TABLE`), and SQLite (`json_each`) are supported.

SQLite has no column types to convert the values to, so values are read as their JSON types
(eg. strings rather than times, and `1`/`0` rather than booleans).

### Sorbet

A Tapioca DSL compiler is included, which adds `virtual_joins` to the relations generated for models
extended by `ActiveRecord::VirtualJoins`. It's loaded automatically by `bin/tapioca dsl`.

## Development

The specs run against a dummy Rails application in `spec/dummy`, using SQLite by default:

```bash
$ bin/rspec
$ bin/rubocop
```

PostgreSQL and MySQL are selected with the `DATABASE_ADAPTER` and `DATABASE_URL` environment variables
(see `.github/workflows/ci.yml`).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
