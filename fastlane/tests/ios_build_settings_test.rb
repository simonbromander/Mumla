require "minitest/autorun"
require "shellwords"
require "yaml"

class IOSBuildSettingsTest < Minitest::Test
  class ReleaseActions
    attr_reader :archive_options, :profile_requests

    def initialize
      @lanes = {}
      @profile_requests = []
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

    def get_provisioning_profile(**options)
      @profile_requests << options
      "profile-#{options.fetch(:app_identifier)}"
    end

    def run_build(options = {})
      @lanes.fetch(:build).call(options)
    end
  end

  def setup
    path = File.expand_path("../Fastfile", __dir__)
    @actions = ReleaseActions.new
    @actions.instance_eval(File.read(path), path)
    @actions.define_singleton_method(:mumla_context) do
      { app: Object.new, api_key: {}, certificate_id: "CERTIFICATE", fingerprint: "FINGERPRINT" }
    end
    # Execute the actual build lane without filesystem, Xcode or Apple API actions.
    reader = ->(path) { { "UUID" => "profile-#{File.basename(path, '.mobileprovision')}" } }
    validator = ->(profile, **) { profile.fetch("UUID") }
    MumlaIOSSigning.stub(:read_profile, reader) do
      MumlaIOSSigning.stub(:validate_profile, validator) do
        MumlaIOSSigning.stub(:configure_project, nil) do
          FileUtils.stub(:mkdir_p, nil) { @actions.run_build }
        end
      end
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
    assert_includes @settings, "CODE_SIGN_STYLE=Manual"
    assert_includes @settings, "CODE_SIGN_IDENTITY=FINGERPRINT"
  end

  def test_each_target_uses_an_explicit_profile_and_matching_certificate
    identifiers = MumlaIOSSigning::TARGETS.values
    assert_equal identifiers, @actions.profile_requests.map { |request| request.fetch(:app_identifier) }
    @actions.profile_requests.each do |request|
      assert_equal "CERTIFICATE", request.fetch(:cert_id)
      assert_equal false, request.fetch(:development)
      assert_equal false, request.fetch(:force)
    end
    options = @actions.archive_options.fetch(:export_options)
    assert_equal "manual", options.fetch(:signingStyle)
    assert_equal "FINGERPRINT", options.fetch(:signingCertificate)
    assert_equal identifiers.to_h { |identifier| [identifier, "profile-#{identifier}"] }, options.fetch(:provisioningProfiles)
    refute @settings.include?("-allowProvisioningUpdates")
  end

  def test_refresh_only_regenerates_the_keyboard_profile
    MumlaIOSSigning.stub(:read_profile, ->(path) { { "UUID" => "profile-#{File.basename(path, '.mobileprovision')}" } }) do
      MumlaIOSSigning.stub(:validate_profile, ->(profile, **) { profile.fetch("UUID") }) do
        MumlaIOSSigning.stub(:configure_project, nil) do
          FileUtils.stub(:mkdir_p, nil) { @actions.run_build(refresh_keyboard_profile: true) }
        end
      end
    end
    requests = @actions.profile_requests.last(3)
    assert_equal ["com.mumla.app.keyboard"], requests.select { |request| request.fetch(:force) }.map { |request| request.fetch(:app_identifier) }
  end
end
