Gem::Specification.new do |spec|
  spec.name          = 'kiket-sdk'
  spec.version       = '0.1.0'
  spec.authors       = [ 'Kiket Team' ]
  spec.email         = [ 'team@kiket.dev' ]

  spec.summary       = 'Official Ruby SDK for building Kiket extensions'
  spec.description   = 'Build and run Kiket extensions with a batteries-included, strongly-typed Ruby toolkit'
  spec.homepage      = 'https://github.com/kiket-dev/kiket-ruby-sdk'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/kiket-dev/kiket-ruby-sdk'
  spec.metadata['changelog_uri'] = 'https://github.com/kiket-dev/kiket-ruby-sdk/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob('{lib,spec}/**/*') + %w[README.md LICENSE]
  spec.require_paths = [ 'lib' ]

  # Runtime dependencies
  spec.add_dependency 'faraday', '~> 2.8'
  spec.add_dependency 'faraday-retry', '~> 2.2'
  spec.add_dependency 'jwt', '~> 2.7'
  spec.add_dependency 'psych', '~> 5.1'
  spec.add_dependency 'puma', '>= 6.4', '< 8'
  spec.add_dependency 'rackup', '~> 2.1'
  spec.add_dependency 'sinatra', '~> 4.0'

  # Development dependencies
  spec.add_development_dependency 'rack-test', '~> 2.1'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.59'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.25'
  spec.add_development_dependency 'webmock', '~> 3.19'
end
