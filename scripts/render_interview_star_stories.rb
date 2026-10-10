#!/usr/bin/env ruby
# Render the interview STAR story bank from the career-history YAML sources.
require 'yaml'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
DATA = File.join(ROOT, 'src/data')
GENERATED = File.join(ROOT, 'build/generated')
PROFILE_PATH = File.join(ROOT, 'src/profiles/master-career-history.yaml')

def load_yaml(path)
  raise "Missing #{path}" unless File.file?(path)
  YAML.load_file(path)
end

def selected_achievements(role, selection)
  records = load_yaml(File.join(DATA, 'achievements', "#{role.fetch('id')}.yaml"))
  by_id = records.to_h { |record| [record.fetch('id'), record] }
  ids = selection.fetch('achievements', 'all')
  ids = role.fetch('achievement_ids') if ids == 'all'
  order = selection['achievement_order']
  if order
    raise "#{role['id']} order must list each selected achievement exactly once" unless order.length == ids.length && order.sort == ids.sort
    ids = order
  end
  ids.map { |id| by_id.fetch(id) { raise "Missing achievement #{id}" } }
end

def star_parts(story, context)
  labels = %w[Situation Task Action Result]
  pattern = /\\textbf\{(Situation|Task|Action|Result):\}\s*/
  matches = []
  cursor = 0
  while (match = pattern.match(story, cursor))
    matches << match
    cursor = match.end(0)
  end

  actual_labels = matches.map { |match| match[1] }
  raise "Malformed STAR story for #{context}: expected #{labels.join(', ')}" unless actual_labels == labels
  raise "Unexpected text before Situation for #{context}" unless story[0...matches.first.begin(0)].strip.empty?

  matches.each_with_index.map do |match, index|
    ending = index + 1 < matches.length ? matches[index + 1].begin(0) : story.length
    text = story[match.end(0)...ending].strip
    raise "Empty #{match[1]} text for #{context}" if text.empty?
    text
  end
end

def role_heading(role)
  title = role.fetch('title_tex')
  return "#{role.fetch('employer')} -- Company-wide Contributions" if role.fetch('kind') == 'company'
  "#{role.fetch('employer')} -- #{title}"
end

profile = load_yaml(PROFILE_PATH)
selections = profile.fetch('roles').map { |entry| entry.is_a?(String) ? { 'id' => entry } : entry }
contact = load_yaml(File.join(DATA, 'contact.yaml'))

roles = selections.map do |selection|
  id = selection.fetch('id')
  raise "Invalid role ID: #{id}" unless id.match?(/\A[a-z0-9-]+\z/)
  role = load_yaml(File.join(DATA, 'roles', "#{id}.yaml"))
  [role, selected_achievements(role, selection)]
end

story_count = roles.sum { |_role, achievements| achievements.length }
FileUtils.mkdir_p(GENERATED)

meta = <<~TEX
  % Generated from src/data/contact.yaml; do not edit.
  \\newcommand{\\contactname}{#{contact.fetch('name_tex')}}
  \\newcommand{\\storycount}{#{story_count}}
TEX
File.write(File.join(GENERATED, 'interview-star-stories-meta.tex'), meta)

index_lines = [
  '% Generated from src/data and src/profiles/master-career-history.yaml; do not edit.',
  '\\begin{itemize}[leftmargin=0.18in,itemsep=3pt,topsep=2pt]'
]
roles.each do |role, achievements|
  id = role.fetch('id')
  index_lines << "  \\item \\hyperref[role:#{id}]{\\textbf{#{role_heading(role)}}} \\hfill \\textcolor{muted}{#{achievements.length} stories \\textbar\ p.~\\pageref{role:#{id}}}"
end
index_lines << '\\end{itemize}'
File.write(File.join(GENERATED, 'interview-star-stories-index.tex'), index_lines.join("\n") + "\n")

content_lines = ['% Generated from src/data and src/profiles/master-career-history.yaml; do not edit.']
roles.each do |role, achievements|
  id = role.fetch('id')
  heading = role_heading(role)
  content_lines << '\\rolebreak'
  content_lines << "\\section{#{heading}}"
  content_lines << "\\label{role:#{id}}"
  content_lines << "\\markright{#{heading}}"
  content_lines << "\\textbf{Dates:} #{role.fetch('dates')}\\par"
  tools = role.fetch('tools_tex')
  content_lines << "\\textbf{Technologies:} #{tools}\\par" unless tools.empty?
  content_lines << "\\smallskip\\textit{#{role.fetch('summary_tex')}}\\par"

  achievements.each do |achievement|
    story = achievement.fetch('story_tex') { raise "Missing story for #{achievement.fetch('id')}" }
    parts = star_parts(story, achievement.fetch('id'))
    content_lines << "\\story{#{achievement.fetch('id')}}{#{achievement.fetch('text_tex')}}{#{parts[0]}}{#{parts[1]}}{#{parts[2]}}{#{parts[3]}}"
  end
end
File.write(File.join(GENERATED, 'interview-star-stories-content.tex'), content_lines.join("\n") + "\n")

puts "Rendered interview STAR story bank (#{roles.length} role records, #{story_count} stories)."
