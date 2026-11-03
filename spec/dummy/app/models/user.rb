# frozen_string_literal: true

class User < ApplicationRecord
  has_many :posts, dependent: :destroy, inverse_of: :user

  validates :name, presence: true
end
