#!/usr/bin/env ruby
# Revoke Apple Development certificates so CI can create a fresh one in the ephemeral keychain.
# Run with fastlane's bundled dependencies on PATH (Homebrew fastlane is fine).

fastlane_bin = ENV["FASTLANE_BIN"]&.strip
fastlane_bin = `command -v fastlane`.strip if fastlane_bin.nil? || fastlane_bin.empty?

if fastlane_bin.empty?
  warn "fastlane not found on PATH"
  exit 1
end

libexec = File.expand_path("../libexec", File.dirname(File.realpath(fastlane_bin)))
spaceship_lib = Dir[File.join(libexec, "gems", "fastlane-*/spaceship/lib")].first

unless spaceship_lib
  warn "Could not locate fastlane spaceship library (FASTLANE_BIN=#{fastlane_bin})"
  exit 1
end

$LOAD_PATH.unshift(spaceship_lib)
require "spaceship/connect_api"

key_id = ENV.fetch("ASC_API_KEY_ID")
issuer_id = ENV.fetch("ASC_API_ISSUER_ID")
key_path = ENV.fetch("ASC_API_KEY_PATH")

token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path
)
Spaceship::ConnectAPI.token = token

certs = Spaceship::ConnectAPI::Certificate.all(
  filter: {
    certificateType: Spaceship::ConnectAPI::Certificate::CertificateType::DEVELOPMENT
  }
)

if certs.empty?
  puts "No Apple Development certificates to revoke."
  exit 0
end

certs.each do |cert|
  name = cert.display_name || cert.name || cert.id
  puts "Revoking development certificate #{cert.id} (#{name})"
  cert.delete!
end

puts "Revoked #{certs.length} development certificate(s)."
