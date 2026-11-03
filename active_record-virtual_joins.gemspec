# frozen_string_literal: true

require_relative 'lib/active_record/virtual_joins/version'

Gem::Specification.new do |spec|
  spec.name        = 'active_record-virtual_joins'
  spec.version     = ActiveRecord::VirtualJoins::VERSION
  spec.authors     = ['Minty Fresh']
  spec.email       = ['7896757+mintyfresh@users.noreply.github.com']
  spec.homepage    = 'https://github.com/mintyfresh/active_record-virtual_joins'
  spec.summary     = 'Join lists of Ruby hashes to ActiveRecord relations'
  spec.description = 'Joins a list of hashes to the records of an ActiveRecord relation as a virtual table, ' \
                     'selecting its values onto the records.'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['lib/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'activerecord', '>= 8.1'
end
