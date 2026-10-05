require "digest"
require "open3"

module MumlaIOSSigning
  class Error < StandardError; end

  TARGETS = {
    "Mumla" => "com.mumla.app",
    "MumlaKeyboard" => "com.mumla.app.keyboard",
    "MumlaWidgets" => "com.mumla.app.widgets"
  }.freeze
  APP_GROUP = "group.com.mumla.app"

  module_function

  def read_profile(path)
    require "plist"
    xml, error, status = Open3.capture3("security", "cms", "-D", "-i", path)
    raise Error, "Cannot decode iOS provisioning profile: #{error}" unless status.success?
    Plist.parse_xml(xml, marshal: false)
  end

  def validate_profile(profile, identifier:, team_id:, fingerprint:, at: Time.now)
    entitlements = profile.fetch("Entitlements")
    expiry = profile.fetch("ExpirationDate")
    expiry = expiry.to_time if expiry.respond_to?(:to_time)
    valid = expiry > at &&
      Array(profile["Platform"]).include?("iOS") &&
      Array(profile["TeamIdentifier"]) == [team_id] &&
      entitlements["application-identifier"] == "#{team_id}.#{identifier}" &&
      entitlements["com.apple.developer.team-identifier"] == team_id &&
      entitlements["get-task-allow"] == false &&
      entitlements["beta-reports-active"] == true &&
      !profile.key?("ProvisionedDevices") && !profile["ProvisionsAllDevices"] &&
      Array(profile["DeveloperCertificates"]).any? do |der|
        Digest::SHA1.hexdigest(der.respond_to?(:string) ? der.string : der).upcase == fingerprint
      end
    raise Error, "Invalid App Store profile or certificate for #{identifier}." unless valid
    unless Array(entitlements["com.apple.security.application-groups"]).include?(APP_GROUP)
      raise Error, "Assign #{APP_GROUP} to #{identifier} in Apple Developer, then regenerate its profile."
    end
    if identifier == TARGETS.fetch("Mumla")
      unless Array(entitlements["com.apple.developer.icloud-container-identifiers"]).include?("iCloud.com.mumla.app") &&
             Array(entitlements["com.apple.developer.icloud-container-environment"]).include?("Production")
        raise Error, "Missing production iCloud capability for #{identifier}."
      end
    end
    profile.fetch("UUID")
  end

  def configure_project(path, profiles)
    require "xcodeproj"
    project = Xcodeproj::Project.open(path)
    TARGETS.each do |name, identifier|
      target = project.targets.find { |item| item.name == name }
      raise Error, "Missing release target #{name}." unless target
      configuration = target.build_configurations.find { |item| item.name == "Release" }
      raise Error, "Missing Release configuration for #{name}." unless configuration
      settings = configuration.build_settings
      raise Error, "Unexpected bundle identity for #{name}." unless settings["PRODUCT_BUNDLE_IDENTIFIER"] == identifier
      settings["CODE_SIGN_STYLE"] = "Manual"
      settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"
      settings["PROVISIONING_PROFILE_SPECIFIER"] = profiles.fetch(identifier)
    end
    project.save
  end
end
