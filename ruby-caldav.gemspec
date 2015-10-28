require File.expand_path('../lib/caldav/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = "caldav"
  s.version     = CalDAV::VERSION
  s.summary     = "Ruby CalDAV client"
  s.description = "Ruby client for CalDAV calendar and tasks."
  s.homepage    = "https://github.com/martinpovolny/ruby-caldav"
  s.authors     = ["Martin Povolny"]
  s.email       = ["martin.povolny@gmail.com"]
  
  s.add_runtime_dependency 'rubysl-rexml'
  s.add_runtime_dependency 'icalendar'
  s.add_runtime_dependency 'uuid'
  s.add_runtime_dependency 'builder'

  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.require_paths = ["lib"]
end
