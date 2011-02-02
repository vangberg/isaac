Gem::Specification.new do |s|
  s.name     = "isaac"
  s.version  = "0.3.0"
  s.date     = "2009-12-21"
  s.summary  = "The smallish DSL for writing IRC bots"
  s.email    = "harry@vangberg.name"
  s.homepage = "http://github.com/ichverstehe/isaac"
  s.description = "Small DSL for writing IRC bots."
  s.rubyforge_project = "isaac"
  s.has_rdoc = true
  s.authors  = ["Harry Vangberg"]
  s.files    = [
    "README.rdoc", 
    "CHANGES",
    "isaac.gemspec", 
    "lib/isaac.rb",
    "lib/isaac/bot.rb"
  ]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.extra_rdoc_files = ["CHANGES", "README.rdoc"]
end

