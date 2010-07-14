# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{git-topic}
  s.version = "0.1.6.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["David J. Hamilton"]
  s.date = %q{2010-07-14}
  s.default_executable = %q{git-topic}
  s.description = %q{
      gem command around reviewed topic branches.  Supports workflow of the form:

      # alexander:
      git work-on <topic>
      git done

      # bismarck:
      git status    # notice a review branch
      git review <topic>
      # happy, merge into master, push and cleanup
      git accept

      git review <topic2>
      # unhappy
      git reject

      # alexander:
      git status    # notice rejected topic
      git work-on <topic>

      see README.rdoc for more (any) details.
    }
  s.email = %q{git-topic@hjdivad.com}
  s.executables = ["git-topic"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".gitignore",
     ".gvimrc",
     ".rspec",
     ".rvmrc",
     ".vimproject",
     ".vimrc",
     "Gemfile",
     "Gemfile.lock",
     "History.txt",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION.yml",
     "autotest/discover.rb",
     "bin/git-topic",
     "git-topic.gemspec",
     "lib/core_ext.rb",
     "lib/git_topic.rb",
     "lib/git_topic/git.rb",
     "lib/git_topic/naming.rb",
     "spec/git_topic_spec.rb",
     "spec/spec_helper.rb",
     "spec/template/origin/HEAD",
     "spec/template/origin/config",
     "spec/template/origin/description",
     "spec/template/origin/hooks/applypatch-msg.sample",
     "spec/template/origin/hooks/commit-msg.sample",
     "spec/template/origin/hooks/post-commit.sample",
     "spec/template/origin/hooks/post-receive.sample",
     "spec/template/origin/hooks/post-update.sample",
     "spec/template/origin/hooks/pre-applypatch.sample",
     "spec/template/origin/hooks/pre-commit.sample",
     "spec/template/origin/hooks/pre-rebase.sample",
     "spec/template/origin/hooks/prepare-commit-msg.sample",
     "spec/template/origin/hooks/update.sample",
     "spec/template/origin/info/exclude",
     "spec/template/origin/objects/0a/da6d051b94cd0df50f5a0b7229aec26f0d2cdf",
     "spec/template/origin/objects/0c/e06c616769768f09f5e629cfcc68eabe3dee81",
     "spec/template/origin/objects/20/049991cdafdce826f5a3c01e10ffa84d6997ec",
     "spec/template/origin/objects/33/1d827fd47fb234af54e3a4bbf8c6705e9116cc",
     "spec/template/origin/objects/41/51899b742fd6b1c873b177b9d13451682089bc",
     "spec/template/origin/objects/44/ffd9c9c8b52b201659e3ad318cdad6ec836b46",
     "spec/template/origin/objects/4b/825dc642cb6eb9a060e54bf8d69288fbee4904",
     "spec/template/origin/objects/55/eeb01bdf874d1a35870bcf24a970c475c63344",
     "spec/template/origin/objects/8d/09f9b8d80ce282218125cb0cbf53cccf022203",
     "spec/template/origin/objects/b4/8e68d5cac189af36abe48e893d11c24b7b2a19",
     "spec/template/origin/objects/c0/838ed2ee8f2e83c8bda859fc5e332b92f0a5a3",
     "spec/template/origin/objects/cd/f7b9dbc4911a0d1404db54cde2ed448f6a6afd",
     "spec/template/origin/objects/d2/6b33daea1ed9823a189992bba38fbc913483c1",
     "spec/template/origin/objects/fe/4e254557e19f338f40ccfdc00a7517771db880",
     "spec/template/origin/refs/heads/master",
     "spec/template/origin/refs/heads/rejected/davidjh/krakens",
     "spec/template/origin/refs/heads/review/davidjh/pirates",
     "spec/template/origin/refs/heads/review/user24601/ninja-basic",
     "spec/template/origin/refs/heads/review/user24601/zombie-basic"
  ]
  s.homepage = %q{http://github.com/hjdivad/git-topic}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{git command around reviewed topic branches}
  s.test_files = [
    "spec/spec_helper.rb",
     "spec/git_topic_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.0.0.beta4"])
      s.add_runtime_dependency(%q<trollop>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 2.0.0.beta.16"])
      s.add_development_dependency(%q<ZenTest>, [">= 0"])
      s.add_development_dependency(%q<yard>, [">= 0"])
      s.add_development_dependency(%q<gemcutter>, [">= 0"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.0.0.beta4"])
      s.add_dependency(%q<trollop>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 2.0.0.beta.16"])
      s.add_dependency(%q<ZenTest>, [">= 0"])
      s.add_dependency(%q<yard>, [">= 0"])
      s.add_dependency(%q<gemcutter>, [">= 0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.0.0.beta4"])
    s.add_dependency(%q<trollop>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 2.0.0.beta.16"])
    s.add_dependency(%q<ZenTest>, [">= 0"])
    s.add_dependency(%q<yard>, [">= 0"])
    s.add_dependency(%q<gemcutter>, [">= 0"])
  end
end

