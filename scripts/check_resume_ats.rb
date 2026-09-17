#!/usr/bin/env ruby
# Check the built ATS PDF's extracted reading order against its YAML profile.
require 'yaml'
require 'open3'
require 'fileutils'
require 'date'

root = File.expand_path('..', __dir__)
pdf = File.join(root, 'build/pdf/resume_ats.pdf')
profile = YAML.load_file(File.join(root, 'src/profiles/resume-ats.yaml'))
cache = File.join(root, 'build/generated/swift-cache')
FileUtils.mkdir_p(cache)
env = { 'CLANG_MODULE_CACHE_PATH' => cache, 'SWIFT_MODULECACHE_PATH' => cache }
output, errors, status = Open3.capture3(env, 'swift', File.join(root, 'scripts/extract_pdf_text.swift'), pdf)
abort "PDF text extraction failed: #{errors}" unless status.success?

page_count, *lines = output.lines.map(&:strip)
abort "ATS resume must be two pages, got #{page_count}" unless page_count == 'PAGE_COUNT=2'
abort 'HSEA must not appear in ATS resume' if output.include?('HSEA')
abort 'PDF contains mis-mapped semicolon glyph' if output.include?("\u037E")
contact = YAML.load_file(File.join(root, 'src/data/contact.yaml'))
%w[name_tex email phone_tex linkedin_display_tex github_display_tex].each do |field|
  abort "Missing contact detail: #{field}" unless output.include?(contact.fetch(field))
end
footer_date = Date.today.strftime('%B %-d, %Y').upcase
(1..page_count.delete_prefix('PAGE_COUNT=').to_i).each do |page|
  footer = "#{footer_date} #{contact.fetch('name_tex')} · Résumé #{page}"
  abort "Missing or duplicate footer on page #{page}" unless lines.count(footer) == 1
end

position = 0
expect_line = lambda do |label|
  offset = lines[position..-1].index(label)
  found = position + offset if offset
  abort "Missing or out-of-order PDF text: #{label}" unless found
  position = found + 1
  found
end

%w[Professional\ Summary Technical\ Skills Professional\ Experience].each { |heading| expect_line.call(heading) }

profile.fetch('roles').each do |selection|
  role = YAML.load_file(File.join(root, 'src/data/roles', "#{selection.fetch('id')}.yaml"))
  heading = "#{role.fetch('employer')} #{role.fetch('dates')}"
  index = expect_line.call(heading)
  abort "Title missing after #{heading}" unless lines[index + 1] == role.fetch('title_tex')
  tools = role.fetch('tools_tex')
  if tools.empty?
    abort "Unexpected technologies after #{heading}" if lines[index + 2]&.start_with?('Technologies:')
  else
    normalized_text = lines[index + 2..].join(' ').gsub(/\s+/, ' ')
    abort "Technologies missing or changed after #{heading}" unless normalized_text.start_with?("Technologies: #{tools}")
  end
  if selection.key?('company_technologies_from')
    company = YAML.load_file(File.join(root, 'src/data/roles', "#{selection.fetch('company_technologies_from')}.yaml"))
    label = "Technologies used across #{company.fetch('employer')} roles:"
    expected = "#{label} #{company.fetch('tools_tex')}"
    normalized_text = lines[index + 2..].join(' ').gsub(/\s+/, ' ')
    abort "Company technologies missing or changed after #{heading}" unless normalized_text.start_with?(expected)
    abort "Company technologies appear more than once: #{company.fetch('employer')}" unless output.scan(label).length == 1
  end
end

expect_line.call('Education')
education = YAML.load_file(File.join(root, 'src/data/sections/education.yaml'))
education_by_id = education.fetch('blocks').to_h { |record| [record.fetch('id'), record] }
profile.fetch('education').each do |id|
  record = education_by_id.fetch(id)
  expect_line.call("#{record.fetch('degree_tex')}, #{record.fetch('institution_tex')}, #{record.fetch('dates_tex')}")
end
expect_line.call('Certifications')
credentials = YAML.load_file(File.join(root, 'src/data/sections/credentials_and_continuing_education.yaml'))
credentials_by_id = credentials.fetch('blocks').to_h { |record| [record.fetch('id'), record] }
profile.fetch('certifications').each do |id|
  record = credentials_by_id.fetch(id)
  expect_line.call("#{record.fetch('credential_tex')}, #{record.fetch('issuer_tex')}, #{record.fetch('dates_tex')}")
end

expected_bullets = profile.fetch('roles').sum { |selection| selection.fetch('achievements').length }
actual_bullets = lines.count { |line| line.start_with?('•') }
abort "Expected #{expected_bullets} bullets, extracted #{actual_bullets}" unless actual_bullets == expected_bullets

puts "Verified ATS PDF: 2 pages, #{profile.fetch('roles').length} ordered roles, #{actual_bullets} bullets, clean extraction."
