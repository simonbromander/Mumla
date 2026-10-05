require "minitest/autorun"
require "tmpdir"
require_relative "../mac_updates"

class MacUpdatesTest < Minitest::Test
  def info
    { "CFBundleIdentifier" => "com.mumla.app", "MumlaDistribution" => "direct",
      "CFBundleVersion" => "33", "CFBundleShortVersionString" => "1.0.1",
      "SUFeedURL" => MumlaMacUpdates::FEED_URL, "SUPublicEDKey" => "test-key",
      "SURequireSignedFeed" => true, "SUVerifyUpdateBeforeExtraction" => true,
      "SUEnableAutomaticChecks" => false, "SUAutomaticallyUpdate" => false,
      "SUAllowsAutomaticUpdates" => false, "SUEnableSystemProfiling" => false }
  end

  def test_configuration_matches_app
    assert_equal "33", MumlaMacUpdates.validate_info!(info, "test-key")["CFBundleVersion"]
  end

  def test_wrong_identity_distribution_feed_or_key_rejected
    %w[CFBundleIdentifier MumlaDistribution SUFeedURL SUPublicEDKey].each do |field|
      assert_raises(MumlaMacUpdates::Error) { MumlaMacUpdates.validate_info!(info.merge(field => "wrong"), "test-key") }
    end
  end

  def test_security_checks_cannot_be_disabled
    %w[SURequireSignedFeed SUVerifyUpdateBeforeExtraction].each do |field|
      assert_raises(MumlaMacUpdates::Error) { MumlaMacUpdates.validate_info!(info.merge(field => false), "test-key") }
    end
  end

  def test_background_updates_and_profiling_cannot_be_enabled
    %w[SUEnableAutomaticChecks SUAutomaticallyUpdate SUAllowsAutomaticUpdates SUEnableSystemProfiling].each do |field|
      assert_raises(MumlaMacUpdates::Error) { MumlaMacUpdates.validate_info!(info.merge(field => true), "test-key") }
    end
  end

  def test_build_version_cannot_be_invalid
    ["0", "-1", "33 beta", ""].each do |build|
      assert_raises(MumlaMacUpdates::Error) { MumlaMacUpdates.validate_info!(info.merge("CFBundleVersion" => build), "test-key") }
    end
  end

  def test_private_or_credentialed_enclosures_are_rejected
    Dir.mktmpdir do |directory|
      path = File.join(directory, "feed.xml")
      ["http://github.com/example", "https://user:token@github.com/example", "https://github.com/simonbromander/Mumla/releases/download/example.zip"].each do |url|
        File.write(path, %(<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:version>33</sparkle:version><enclosure url="#{url}" length="1" sparkle:edSignature="signed"/></item></channel></rss>))
        assert_raises(MumlaMacUpdates::Error) { MumlaMacUpdates.feed_items(path) }
      end
    end
  end
end
