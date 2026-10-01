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
end
