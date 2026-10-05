require "minitest/autorun"
require "date"
require "stringio"
require_relative "../ios_signing"

class IOSSigningTest < Minitest::Test
  TEAM = "PF2PWR4YG4"
  IDENTIFIER = "com.mumla.app.keyboard"
  CERTIFICATE = "test-certificate-der"
  FINGERPRINT = Digest::SHA1.hexdigest(CERTIFICATE).upcase
  NOW = Time.utc(2026, 10, 5)

  def setup
    @profile = {
      "UUID" => "test-profile", "ExpirationDate" => NOW + 86_400,
      "Platform" => ["iOS"], "TeamIdentifier" => [TEAM],
      "DeveloperCertificates" => [CERTIFICATE],
      "Entitlements" => {
        "application-identifier" => "#{TEAM}.#{IDENTIFIER}",
        "com.apple.developer.team-identifier" => TEAM,
        "get-task-allow" => false, "beta-reports-active" => true,
        "com.apple.security.application-groups" => [MumlaIOSSigning::APP_GROUP]
      }
    }
  end

  def validate(identifier: IDENTIFIER)
    MumlaIOSSigning.validate_profile(@profile, identifier: identifier, team_id: TEAM,
                                    fingerprint: FINGERPRINT, at: NOW)
  end

  def test_distribution_profile_with_group_and_local_certificate_passes
    assert_equal "test-profile", validate
  end

  def test_plist_parser_date_and_binary_certificate_types
    @profile["ExpirationDate"] = DateTime.new(2026, 10, 6)
    @profile["DeveloperCertificates"] = [StringIO.new(CERTIFICATE)]
    assert_equal "test-profile", validate
  end

  def test_missing_app_group_fails_before_archive
    @profile["Entitlements"]["com.apple.security.application-groups"] = []
    error = assert_raises(MumlaIOSSigning::Error) { validate }
    assert_includes error.message, "Assign group.com.mumla.app"
  end

  def test_wrong_bundle_identity_fails
    @profile["Entitlements"]["application-identifier"] = "#{TEAM}.com.mumla.app"
    assert_raises(MumlaIOSSigning::Error) { validate }
  end

  def test_wrong_team_fails
    @profile["TeamIdentifier"] = ["OTHERTEAM"]
    assert_raises(MumlaIOSSigning::Error) { validate }
  end

  def test_expired_profile_fails
    @profile["ExpirationDate"] = NOW
    assert_raises(MumlaIOSSigning::Error) { validate }
  end

  def test_certificate_without_local_private_key_fails
    @profile["DeveloperCertificates"] = ["other-certificate"]
    assert_raises(MumlaIOSSigning::Error) { validate }
  end

  def test_development_adhoc_and_enterprise_profiles_fail
    @profile["Entitlements"]["get-task-allow"] = true
    assert_raises(MumlaIOSSigning::Error) { validate }
    @profile["Entitlements"]["get-task-allow"] = false
    @profile["ProvisionedDevices"] = ["test-device"]
    assert_raises(MumlaIOSSigning::Error) { validate }
    @profile.delete("ProvisionedDevices")
    @profile["ProvisionsAllDevices"] = true
    assert_raises(MumlaIOSSigning::Error) { validate }
  end

  def test_containing_app_requires_production_icloud
    @profile["Entitlements"]["application-identifier"] = "#{TEAM}.com.mumla.app"
    assert_raises(MumlaIOSSigning::Error) { validate(identifier: "com.mumla.app") }
    @profile["Entitlements"].merge!(
      "com.apple.developer.icloud-container-identifiers" => ["iCloud.com.mumla.app"],
      "com.apple.developer.icloud-container-environment" => ["Production", "Development"]
    )
    assert_equal "test-profile", validate(identifier: "com.mumla.app")
  end
end
