require "digest"
require "open3"
require "openssl"

module MumlaDirectSigning
  class Error < StandardError; end

  module_function

  def identity(team_id:)
    identities, error, status = Open3.capture3("security", "find-identity", "-v", "-p", "codesigning")
    raise Error, "Cannot inspect local signing identities: #{error}" unless status.success?

    certificates, error, status = Open3.capture3("security", "find-certificate", "-a", "-p")
    raise Error, "Cannot inspect local signing certificates: #{error}" unless status.success?

    fingerprint = select_identity(certificates: certificates, identities: identities, team_id: team_id)
    unless fingerprint
      raise Error, "Install an unexpired Developer ID Application certificate for #{team_id} " \
                   "with its matching private key. A .cer alone is not a signing identity. " \
                   "Create the certificate using this Mac's CSR, or import a password-protected .p12."
    end
    fingerprint
  end

  def select_identity(certificates:, identities:, team_id:, at: Time.now)
    valid_fingerprints = identities.scan(/^\s*\d+\)\s+([A-F0-9]{40})\s/).flatten
    candidates = certificates.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |pem|
      OpenSSL::X509::Certificate.new(pem)
    end.select do |certificate|
      subject = certificate.subject.to_a
      subject.any? { |name, value, _| name == "OU" && value == team_id } &&
        subject.any? { |name, value, _| name == "CN" && value.start_with?("Developer ID Application:") } &&
        certificate.not_before <= at && certificate.not_after > at &&
        valid_fingerprints.include?(Digest::SHA1.hexdigest(certificate.to_der).upcase)
    end
    certificate = candidates.max_by(&:not_after)
    Digest::SHA1.hexdigest(certificate.to_der).upcase if certificate
  end

  def sparkle_signing_targets(app:)
    framework = File.join(app, "Contents", "Frameworks", "Sparkle.framework", "Versions", "B")
    [File.join(framework, "XPCServices", "Downloader.xpc"),
     File.join(framework, "XPCServices", "Installer.xpc"),
     File.join(framework, "Updater.app"), File.join(framework, "Autoupdate"),
     File.join(app, "Contents", "Frameworks", "Sparkle.framework"), app]
  end

  def sign_sparkle(app:, identity:)
    targets = sparkle_signing_targets(app: app)
    missing = targets.reject { |target| File.exist?(target) }
    raise Error, "Missing pinned Sparkle signing targets: #{missing.join(", ")}" unless missing.empty?
    # Sign inside-out: Xcode's framework copy phase can leave nested helpers ad-hoc signed.
    targets.each do |target|
      _, error, status = Open3.capture3("codesign", "--force", "--sign", identity,
                                      "--timestamp", "--options", "runtime",
                                      "--preserve-metadata=identifier,entitlements", target)
      raise Error, "Cannot sign #{File.basename(target)}: #{error}" unless status.success?
    end
  end
end
