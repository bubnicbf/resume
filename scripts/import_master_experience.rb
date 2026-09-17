#!/usr/bin/env ruby
# One-time, mechanical import of the professional-experience section.
# Do not rerun after editing the YAML inventory: YAML becomes the source of truth.
require 'yaml'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
SOURCE = File.join(ROOT, 'src/content/master_career_history/professional_experience.tex')
DATA = File.join(ROOT, 'src/data')

ROLE_IDS = {
  'HHAeXchange' => 'hhax',
  'GrowData Analytics' => 'growdata',
  'Adonis' => 'adonis',
  'Arkos Health' => 'arkos',
  'Merative' => 'merative',
  'Explorys, an IBM Company' => 'explorys',
  'AmTrust Financial Services' => 'amtrust',
  'PPG Industries' => 'ppg'
}.freeze

IBM_IDS = {
  'Senior Data Scientist' => 'ibm-senior-data-scientist',
  'Senior Data Architect' => 'ibm-senior-data-architect',
  'Data Architect' => 'ibm-data-architect',
  'Software Developer, Data Platform' => 'ibm-software-developer',
  'Data Scientist' => 'ibm-data-scientist'
}.freeze

def args(line, command)
  match = line.match(/^\\#{command}\{([^}]*)\}\{([^}]*)\}(?:\{([^}]*)\})?(?:\{([^}]*)\})?/)
  raise "Cannot parse #{command}: #{line}" unless match
  match.captures
end

def save_entry(entry)
  return unless entry
  bullets = entry.delete('bullets')
  entry['achievement_ids'] = bullets.each_index.map { |i| format('%s-%02d', entry['id'], i + 1) }
  role_path = File.join(DATA, 'roles', "#{entry['id']}.yaml")
  achievement_path = File.join(DATA, 'achievements', "#{entry['id']}.yaml")
  raise "Refusing to overwrite #{role_path}" if File.exist?(role_path) || File.exist?(achievement_path)
  File.write(role_path, YAML.dump(entry))
  File.write(achievement_path, YAML.dump(bullets.each_with_index.map do |bullet, i|
    { 'id' => entry['achievement_ids'][i], 'text_tex' => bullet }
  end))
end

FileUtils.mkdir_p(File.join(DATA, 'roles'))
FileUtils.mkdir_p(File.join(DATA, 'achievements'))
entry = nil
in_items = false

File.foreach(SOURCE).with_index(1) do |raw, line_number|
  line = raw.strip
  if line.start_with?('\\role{')
    save_entry(entry)
    employer, dates, title, tools = args(line, 'role')
    entry = {
      'id' => ROLE_IDS.fetch(employer), 'kind' => 'role',
      'employer' => employer, 'title_tex' => title, 'dates' => dates,
      'tools_tex' => tools, 'summary_tex' => '',
      'source' => "master_career_history/professional_experience.tex:#{line_number}",
      'bullets' => []
    }
  elsif line.start_with?('\\textbf{IBM}')
    save_entry(entry)
    entry = {
      'id' => 'ibm', 'kind' => 'company', 'employer' => 'IBM',
      'title_tex' => '', 'dates' => line[/\\hfill (.+?)\\\\/, 1],
      'tools_tex' => '', 'summary_tex' => '',
      'source' => "master_career_history/professional_experience.tex:#{line_number}",
      'bullets' => []
    }
  elsif line.start_with?('\\subrole{')
    save_entry(entry)
    title, dates = args(line, 'subrole')
    entry = {
      'id' => IBM_IDS.fetch(title), 'kind' => 'subrole', 'employer' => 'IBM',
      'title_tex' => title, 'dates' => dates, 'tools_tex' => '',
      'summary_tex' => '',
      'source' => "master_career_history/professional_experience.tex:#{line_number}",
      'bullets' => []
    }
  elsif line == '\\begin{itemize}'
    in_items = true
  elsif line == '\\end{itemize}'
    in_items = false
  elsif entry && line.start_with?('\\item ')
    entry['bullets'] << line.sub(/^\\item\s+/, '')
  elsif entry && !in_items && !line.empty? && !line.start_with?('\\section', '\\phantomsection', '\\label')
    if entry['id'] == 'ibm' && line.start_with?('\\textit{Technologies: ')
      entry['tools_tex'] = line.sub(/^\\textit\{Technologies: /, '').sub(/\}\s*$/, '')
    else
      entry['summary_tex'] += ' ' unless entry['summary_tex'].empty?
      entry['summary_tex'] += line.sub(/\\\\\[-1pt\]\s*$/, '').sub(/\\\\\s*$/, '')
    end
  end
end
save_entry(entry)
puts "Imported #{Dir.glob(File.join(DATA, 'roles', '*.yaml')).length} roles."
