# frozen_string_literal: true

require_relative "lib/robot_lab/discovery/version"

Gem::Specification.new do |spec|
  spec.name = "robot_lab-discovery"
  spec.version = RobotLab::Discovery::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "Zero-configuration mDNS/DNS-SD robot discovery for RobotLab on local networks."
  spec.description = "Allows RobotLab robots to advertise themselves and discover each other " \
                     "on a local network using multicast DNS (mDNS/Bonjour/Avahi) via the zeroconf gem."
  spec.homepage = "https://github.com/MadBomber/robot_lab-discovery"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "zeroconf", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
