require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "rexml/document"
require "tmpdir"
require "uri"

module MumlaMacUpdates
  FEED_URL = "https://raw.githubusercontent.com/simonbromander/Mumla-Releases/main/appcast.xml"
  REPO_URL = "https://github.com/simonbromander/Mumla-Releases"
  ACCOUNT = "com.mumla.app"
  TEAM = "PF2PWR4YG4"
  class Error < StandardError; end

  def self.run!(*command)
    output, error, status = Open3.capture3(*command)
    raise Error, "#{File.basename(command.first)} failed: #{error.strip}" unless status.success?
    output
  end

  def self.validate_info!(info, public_key)
    raise Error, "Wrong bundle or distribution" unless info["CFBundleIdentifier"] == ACCOUNT && info["MumlaDistribution"] == "direct"
    raise Error, "Wrong update feed or signing key" unless info["SUFeedURL"] == FEED_URL && info["SUPublicEDKey"] == public_key.strip
    raise Error, "Feed/archive verification required" unless info["SURequireSignedFeed"] == true && info["SUVerifyUpdateBeforeExtraction"] == true
    raise Error, "Automatic installation/profiling is not allowed" unless %w[SUEnableAutomaticChecks SUAutomaticallyUpdate SUAllowsAutomaticUpdates SUEnableSystemProfiling].all? { |key| info[key] == false }
    raise Error, "Invalid build number" unless info["CFBundleVersion"].to_s.match?(/\A[1-9]\d*\z/)
    raise Error, "Invalid marketing version" unless info["CFBundleShortVersionString"].to_s.match?(/\A\d+\.\d+\.\d+\z/)
    info
  end

  def self.feed_items(path)
    text = File.read(path)
    raise Error, "DOCTYPE is not allowed in appcast" if text.include?("<!DOCTYPE")
    document = REXML::Document.new(text)
    REXML::XPath.match(document, "/rss/channel/item").map do |item|
      enclosure = item.elements["enclosure"] or raise Error, "Missing enclosure"
      version = item.elements["sparkle:version"]&.text.to_s
      raise Error, "Invalid feed build" unless version.match?(/\A[1-9]\d*\z/)
      url = enclosure.attributes["url"].to_s
      uri = URI.parse(url)
      unless uri.scheme == "https" && uri.host == "github.com" && uri.userinfo.nil? && uri.query.nil? &&
             uri.path.match?(%r{\A/simonbromander/Mumla-Releases/releases/download/macos-\d+\.\d+\.\d+-[1-9]\d*/Mumla-\d+\.\d+\.\d+-[1-9]\d*\.zip\z})
        raise Error, "Unexpected public download URL"
      end
      signature = enclosure.attributes["sparkle:edSignature"].to_s
      raise Error, "Missing archive signature" if signature.empty?
      { build: Integer(version), url: url, signature: signature, length: Integer(enclosure.attributes["length"]) }
    end
  end

  def self.prepare(zip:, output:, sparkle_bin:, notes:, previous_feed: nil)
    raise Error, "Output must be empty" if File.exist?(output) && !Dir.empty?(output)
    key = run!(File.join(sparkle_bin, "generate_keys"), "--account", ACCOUNT, "-p").strip
    info = nil
    Dir.mktmpdir("MumlaUpdateVerify-") do |directory|
      run!("ditto", "-x", "-k", File.expand_path(zip), directory)
      raise Error, "Archive must contain only Mumla.app" unless Dir.children(directory).reject { |name| name == "__MACOSX" } == ["Mumla.app"]
      app = File.join(directory, "Mumla.app")
      info = JSON.parse(run!("plutil", "-convert", "json", "-o", "-", File.join(app, "Contents/Info.plist")))
      validate_info!(info, key)
      run!("codesign", "--verify", "--deep", "--strict", app)
      _, signature, status = Open3.capture3("codesign", "-dv", "--verbose=4", app)
      raise Error, "Expected team's Developer ID signature" unless status.success? && signature.include?("Authority=Developer ID Application:") && signature.include?("TeamIdentifier=#{TEAM}")
      entitlements = run!("codesign", "-d", "--entitlements", ":-", app)
      raise Error, "Sandbox/debug entitlements prohibited" if entitlements.match?(/com.apple.security.(app-sandbox|get-task-allow)/)
      run!("xcrun", "stapler", "validate", app)
      run!("spctl", "--assess", "--type", "execute", app)
      raise Error, "Sparkle not embedded" unless File.directory?(File.join(app, "Contents/Frameworks/Sparkle.framework"))
    end
    if previous_feed
      run!(File.join(sparkle_bin, "sign_update"), "--account", ACCOUNT, "--verify", File.expand_path(previous_feed))
      latest = feed_items(previous_feed).map { |item| item.fetch(:build) }.max || 0
      raise Error, "Build must increase beyond #{latest}" unless Integer(info.fetch("CFBundleVersion")) > latest
    end
    build = info.fetch("CFBundleVersion")
    version = info.fetch("CFBundleShortVersionString")
    tag = "macos-#{version}-#{build}"
    name = "Mumla-#{version}-#{build}"
    FileUtils.mkdir_p(output)
    archive = File.join(output, "#{name}.zip")
    FileUtils.cp(zip, archive)
    FileUtils.cp(notes, File.join(output, "#{name}.md"))
    feed = File.join(output, "appcast.xml")
    FileUtils.cp(previous_feed, feed) if previous_feed
    run!(File.join(sparkle_bin, "generate_appcast"), "--account", ACCOUNT,
         "--download-url-prefix", "#{REPO_URL}/releases/download/#{tag}/",
         "--embed-release-notes", "--full-release-notes-url", "#{REPO_URL}/releases/tag/#{tag}",
         "--link", REPO_URL, "--maximum-deltas", "0", "--channel", "beta", "--versions", build, output)
    run!(File.join(sparkle_bin, "sign_update"), "--account", ACCOUNT, "--verify", feed)
    item = feed_items(feed).find { |entry| entry.fetch(:build) == Integer(build) }
    raise Error, "Generated feed does not match ZIP" unless item && item.fetch(:length) == File.size(archive)
    run!(File.join(sparkle_bin, "sign_update"), "--account", ACCOUNT, "--verify", archive, item.fetch(:signature))
    digest = Digest::SHA256.file(archive).hexdigest
    File.write("#{archive}.sha256", "#{digest}  #{File.basename(archive)}\n")
    { tag: tag, build: build, version: version, zip: archive, checksum: "#{archive}.sha256", feed: feed, sha256: digest }
  end

  def self.verify_public(feed:, sparkle_bin:)
    run!(File.join(sparkle_bin, "sign_update"), "--account", ACCOUNT, "--verify", File.expand_path(feed))
    items = feed_items(feed)
    raise Error, "Empty feed" if items.empty?
    Dir.mktmpdir("MumlaPublicUpdates-") do |directory|
      items.each do |item|
        archive = File.join(directory, "#{item.fetch(:build)}.zip")
        run!("curl", "--fail", "--silent", "--show-error", "--location", "--proto", "=https", "--proto-redir", "=https", "--output", archive, item.fetch(:url))
        raise Error, "Public ZIP size differs" unless File.size(archive) == item.fetch(:length)
        run!(File.join(sparkle_bin, "sign_update"), "--account", ACCOUNT, "--verify", archive, item.fetch(:signature))
      end
    end
    { verified_public_builds: items.map { |item| item.fetch(:build) } }
  end
end

if $PROGRAM_NAME == __FILE__
  action = ARGV.shift
  options = {}
  OptionParser.new do |parser|
    %w[zip output sparkle-bin notes previous-feed feed].each do |key|
      parser.on("--#{key} VALUE") { |value| options[key.tr("-", "_").to_sym] = value }
    end
  end.parse!
  begin
    result = case action
             when "prepare" then MumlaMacUpdates.prepare(**options)
             when "verify-public" then MumlaMacUpdates.verify_public(**options)
             else raise MumlaMacUpdates::Error, "Use prepare or verify-public"
             end
    puts JSON.pretty_generate(result)
  rescue MumlaMacUpdates::Error, ArgumentError => error
    warn error.message
    exit 1
  end
end
