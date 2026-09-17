#!/usr/bin/env ruby
# Check the built ATS PDF's extracted reading order against its YAML profile.
require 'yaml'
require 'open3'
require 'fileutils'

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
  title = selection.fetch('title_tex', role.fetch('title_tex'))
  abort "Title missing after #{heading}" unless lines[index + 1] == title
end

expect_line.call('Education')
education = YAML.load_file(File.join(root, 'src/data/sections/education.yaml'))
education_by_id = education.fetch('blocks').to_h { |record| [record.fetch('id'), record] }
profile.fetch('education').each do |id|
  record = education_by_id.fetch(id)
  expect_line.call("#{record.fetch('degree_tex')}, #{record.fetch('institution_tex')}, #{record.fetch('dates_tex')}")
end
expect_line.call('Certifications')
expect_line.call('Certificate of Specialization in Data Science, Johns Hopkins University, 2015')
expect_line.call('IBM Data Science Professional Certificate, IBM, 2022')

expected_bullets = profile.fetch('roles').sum { |selection| selection.fetch('achievements').length }
actual_bullets = lines.count { |line| line.start_with?('•') }
abort "Expected #{expected_bullets} bullets, extracted #{actual_bullets}" unless actual_bullets == expected_bullets

puts "Verified ATS PDF: 2 pages, #{profile.fetch('roles').length} ordered roles, #{actual_bullets} bullets, clean extraction."
