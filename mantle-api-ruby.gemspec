# mantle-api-ruby.gemspec

Gem::Specification.new do |spec|
  spec.name          = "mantle-api-ruby"
  spec.version       = "0.1.0"
  spec.authors       = ["Joshua Gosse"]
  spec.email         = ["josh@heymantle.com"]

  spec.summary       = "A Ruby SDK for Mantle App API"
  spec.description   = "Connect to the Mantle App API to identify your users and enrich your data, as well as to send events to Mantle."
  spec.homepage      = "https://heymantle.com"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb", "spec/**/*.rb", "Gemfile", "README.md", "LICENSE"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'solargraph'
end
