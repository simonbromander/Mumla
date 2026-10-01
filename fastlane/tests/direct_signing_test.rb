require "minitest/autorun"
require_relative "../direct_signing"

class DirectSigningTest < Minitest::Test
  TEAM = "PF2PWR4YG4"
  NOW = Time.utc(2026, 10, 1, 12)

  def setup
    @key = OpenSSL::PKey::RSA.new(2048)
  end

  def certificate(name: "Developer ID Application: Mumla", team: TEAM, from: NOW - 60, until_time: NOW + 3600)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.new([["CN", name], ["OU", team]])
    cert.issuer = cert.subject
    cert.public_key = @key.public_key
    cert.not_before = from
    cert.not_after = until_time
    cert.sign(@key, OpenSSL::Digest.new("SHA256"))
    cert
  end

  def fingerprint(cert)
    Digest::SHA1.hexdigest(cert.to_der).upcase
  end

  def identities(*certs)
    certs.each_with_index.map { |cert, index| "  #{index + 1}) #{fingerprint(cert)} \"Signing identity\"" }.join("\n")
  end

  def select(*certs, local: certs)
    MumlaDirectSigning.select_identity(certificates: certs.map(&:to_pem).join,
                                      identities: identities(*local), team_id: TEAM, at: NOW)
  end

  def test_accepts_valid_local_application_identity
    cert = certificate
    assert_equal fingerprint(cert), select(cert)
  end

  def test_rejects_certificate_without_private_key_identity
    assert_nil select(certificate, local: [])
  end

  def test_rejects_installer_certificate
    assert_nil select(certificate(name: "Developer ID Installer: Mumla"))
  end

  def test_rejects_apple_distribution_certificate
    assert_nil select(certificate(name: "Apple Distribution: Mumla"))
  end

  def test_rejects_another_team
    assert_nil select(certificate(team: "OTHERTEAM1"))
  end

  def test_rejects_expired_certificate
    assert_nil select(certificate(until_time: NOW))
  end

  def test_rejects_future_certificate
    assert_nil select(certificate(from: NOW + 60))
  end

  def test_chooses_longest_valid_certificate
    first = certificate
    second = certificate(until_time: NOW + 7200)
    assert_equal fingerprint(second), select(first, second)
  end

  def test_ignores_longer_certificate_without_local_identity
    first = certificate
    second = certificate(until_time: NOW + 7200)
    assert_equal fingerprint(first), select(first, second, local: [first])
  end

  def test_empty_keychain_has_no_identity
    assert_nil select
  end
end
