# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    user

    sequence(:slug) { |n| "#{Faker::Internet.slug}-#{n}" }
  end
end
