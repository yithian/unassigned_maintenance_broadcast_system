#!/usr/bin/env ruby

require 'json' # to parse the dedicated portal API responses
require 'net/http' # to query the dedicated portal API
require 'net/smtp' # to send the report email
require 'time' # to compare maintenance times
require 'securerandom' # to generate a unique ID for the report email

USER=ENV['DEDICATED_USER'].chomp
TOKEN=ENV['DEDICATED_TOKEN'].chomp
FROM=ENV['EMAIL_SENDER'].chomp
TO=ENV['EMAIL_RECIPIENT'].chomp
REPO=ENV['SOURCE_REPO'].chomp
NAMESPACE=ENV['NAMESPACE'].chomp
CLUSTER=ENV['CLUSTER'].chomp

if USER.nil? or TOKEN.nil? or FROM.nil? or TO.nil?
  puts 'a config item is empty. Exiting...'
  exit 1
end

BASE='https://dedicated.openshift.com'

NOW = Time.now.utc
# 60 seconds * 60 = 1 hour * 24 = 1 day * 3 = 3 days)
SOON = NOW + (60 * 60 * 24 * 3)

# call the dedicated portal API and return the result as a ruby object
def api_call(path)
  uri = URI("#{BASE}/api/#{path}?authorization_username=#{USER}")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{TOKEN}"

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  unless res.is_a?(Net::HTTPSuccess)
    puts res.inspect
    exit
  end

  return JSON.parse(res.body)
end

# send an email to the team list
def email(body)
  message = <<EOM
From: #{FROM}
To: #{TO}
Date: #{NOW.rfc822}
Message-Id: #{SecureRandom.uuid}@redhat.com
Subject: Unassigned upcoming maintenances

Region Leads - please arrange coverage for these maintenances immediately:

#{body}

---
This message has been sent by the Unassigned Maintenance Broadcast System.
This utility runs in the #{NAMESPACE} namespace on #{CLUSTER}.
The source code for this utility can be found at #{REPO} .
EOM

  Net::SMTP.start('smtp.corp.redhat.com', 25, FROM) do |smtp|
    smtp.send_message message, FROM, TO
  end
end

body = []

api_call('/master_maintenances').each do |mm|
  # the master maintenance provided by `GET /api/master_maintenances` is a stub.
  # we need the full info provided by `GET /api/master_maintenances/$ID`
  mm = api_call("/master_maintenances/#{mm['id']}")

  next if mm['scheduled_maintenances'].nil? 

  # filter for schedules on the master maintenance with
  # 1: a schedule
  # 2: a start time for the schedule
  # 3: incident notes
  selected_schedules = mm['scheduled_maintenances'].select do |s|
    s['selected_schedule'] and s['selected_schedule']['start'] and
      s['incident_notes']
  end

  # filter further for schedules that are unassigned.
  # this isn't exposed via the API so we have to interpret from the incident notes:
  # if there are an equal number of "no longer scheduled" messages, it shouldn't
  # be assigned to anyone
  unassigned_schedules = selected_schedules.select do |s|
    start = Time.parse(s['selected_schedule']['start'])

    if start.between?(NOW,SOON)
      assigned = s['incident_notes'].scan('is now scheduled').count
      unassigned = s['incident_notes'].scan('is no longer scheduled').count

      assigned <= unassigned
    end
  end

  # output for this master maintenance if one of its schedules is unassigned
  unless unassigned_schedules.empty?
    body << "Title: #{mm['title']}"
    body << "URL: #{BASE}/admin/master_maintenances/#{mm['id']}/dashboard"
    unassigned_schedules.each do |u_s|
      body << "Unassigned maintenance for #{u_s['cluster']['name']} starting at #{u_s['selected_schedule']['start']}"
    end
    body << ''
  end
end

email(body.join("\n")) unless body.empty?
