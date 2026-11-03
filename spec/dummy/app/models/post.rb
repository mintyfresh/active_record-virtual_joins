# frozen_string_literal: true

class Post < ApplicationRecord
  belongs_to :user, inverse_of: :posts

  validates :slug, presence: true, uniqueness: true
end
