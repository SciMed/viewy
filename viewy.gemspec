$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'viewy/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'viewy'
  s.version     = Viewy::VERSION
  s.authors     = ['Emerson Huitt']
  s.email       = ['emerson.huitt@scimedsolutions.com']
  s.homepage    = 'https://github.com/SciMed/viewy'
  s.summary     = 'Viewy is a tool for managing views in Rails applications'
  s.description = 'Viewy is a tool for managing views and materialized views in Postgres from within a rails app.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.rdoc']

  s.add_dependency 'rails', '~> 4'

  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'shoulda-matchers'
end
