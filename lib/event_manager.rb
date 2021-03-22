# frozen_string_literal: true

require 'csv'
require 'date'
require 'erb'
require 'google/apis/civicinfo_v2'

DATE_PARSE = '%m/%d/%y %k:%M'
reg_hour = Hash.new(0)
reg_day = Hash.new(0)
active_hours = []
active_days = []

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s
  phone_number.gsub!(/\D/, '')
  length = phone_number.length

  if length == 10 || (length == 11 && phone_number[0] == '1')
    phone_number[-10..-1]
  else
    'bad phone number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]

  day_time = DateTime.strptime(row[:regdate], DATE_PARSE)
  day = day_time.strftime('%A')
  reg_hour[day_time.hour] += 1
  reg_day[day_time.wday] += 1

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

reg_hour.each { |k, v| active_hours << k if v == reg_hour.values.max }
reg_day.each { |k, v| active_days << k if v == reg_day.values.max }

puts "The most common registration #{(active_hours.length == 1 ? 'hour is ' : 'hours are ') + active_hours.join(' and ')}."
puts "The most common registration #{(active_days.length == 1 ? 'day is ' : 'days are ') + active_days.join(' and ')}."
