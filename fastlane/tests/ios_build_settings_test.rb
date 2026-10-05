require "minitest/autorun"
require "shellwords"
require "yaml"

class IOSBuildSettingsTest < Minitest::Test
  class ReleaseActions
    attr_reader :archive_options

    def initialize
      @lanes = {}
    end

    def default_platform(*)
    end

    def platform(*)
      yield
    end

    def desc(*)
    end

    def lane(name, &block)
      @lanes[name] = block
    end

    def sh(*)
    end

    def latest_testflight_build_number(**)
      27
    end

    def build_app(**options)
      @archive_options = options
    end

    def run_build
      @lanes.fetch(:build).call
    end
  end

  def setup
    path = File.expand_path("../Fastfile", __dir__)
    @actions = ReleaseActions.new
    @actions.instance_eval(File.read(path), path)
    @actions.define_singleton_method(:mumla_context) { { app: Object.new, api_key: {} } }
    credentials = { "ASC_KEY_PATH" => "/tmp/test-key.p8", "ASC_KEY_ID" => "TEST", "ASC_ISSUER_ID" => "TEST" }
    # Execute the actual build lane without filesystem, Xcode or Apple API actions.
    ENV.stub(:fetch, ->(key) { credentials.fetch(key) }) do
      FileUtils.stub(:mkdir_p, nil) { @actions.run_build }
    end
    @settings = Shellwords.split(@actions.archive_options.fetch(:xcargs))
  end

  def test_release_does_not_override_every_targets_bundle_identity
    refute @settings.any? { |setting| setting.start_with?("PRODUCT_BUNDLE_IDENTIFIER=") }
    project = YAML.safe_load(File.read(File.expand_path("../../project.yml", __dir__)))
    expected = { "Mumla" => "com.mumla.app", "MumlaKeyboard" => "com.mumla.app.keyboard", "MumlaWidgets" => "com.mumla.app.widgets" }
    expected.each do |target, identifier|
      assert_equal identifier, project.dig("targets", target, "settings", "base", "PRODUCT_BUNDLE_IDENTIFIER")
    end
  end

  def test_release_uses_one_version_build_and_team_for_all_targets
    assert_includes @settings, "MARKETING_VERSION=1.0.1"
    assert_includes @settings, "CURRENT_PROJECT_VERSION=28"
    assert_includes @settings, "DEVELOPMENT_TEAM=PF2PWR4YG4"
    assert_includes @settings, "CODE_SIGN_STYLE=Automatic"
  end
end
