#!/usr/bin/env ruby
# Render a selected career-history profile to LaTeX. Ruby's YAML library is built in.
require 'yaml'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
DATA = File.join(ROOT, 'src/data')
GENERATED = File.join(ROOT, 'build/generated')
PROFILES = File.join(ROOT, 'src/profiles')
SECTION_FIELDS = {
  'record' => %w[name_tex dates_tex description_tex],
  'degree' => %w[degree_tex institution_tex dates_tex description_tex],
  'certification' => %w[credential_tex issuer_tex dates_tex],
  'compactrecord' => %w[name_tex dates_tex],
  'presentation' => %w[title_tex venue_tex dates_tex description_tex],
  'subrole' => %w[title_tex dates_tex]
}.freeze

def load_yaml(path)
  raise "Missing #{path}" unless File.file?(path)
  YAML.load_file(path)
end

def braces(value)
  "{#{value}}"
end

def apply_order(ids, order, context)
  return ids unless order
  raise "#{context} order must list each selected ID exactly once" unless order.length == ids.length && order.sort == ids.sort
  order
end

def selected_items(role, selection)
  records = load_yaml(File.join(DATA, 'achievements', "#{role.fetch('id')}.yaml"))
  by_id = records.to_h { |record| [record.fetch('id'), record.fetch('text_tex')] }
  ids = selection.fetch('achievements', 'all')
  ids = role.fetch('achievement_ids') if ids == 'all'
  raise "Duplicate achievements in #{role['id']}" unless ids.uniq == ids
  ids = apply_order(ids, selection['achievement_order'], role['id'])
  ids.map do |id|
    raise "#{id} does not belong to #{role['id']}" unless role.fetch('achievement_ids').include?(id)
    by_id.fetch(id) { raise "Missing achievement #{id}" }
  end
end

def ats_entry(role, selection)
  raise "ATS profile requires individual roles: #{role['id']}" if role.fetch('kind') == 'company'
  raise "ATS technologies must come from the role record: #{role['id']}" if selection.key?('tools_tex')
  lines = ["\\atsrole#{braces(role.fetch('employer'))}#{braces(role.fetch('title_tex'))}#{braces(role.fetch('dates'))}"]
  tools = role.fetch('tools_tex')
  lines << "\\textit{Technologies: #{tools}}\\par" unless tools.empty?
  if selection.key?('company_technologies_from')
    company_id = selection.fetch('company_technologies_from')
    raise "Invalid ATS company ID: #{company_id}" unless company_id.match?(/\A[a-z0-9-]+\z/)
    company = load_yaml(File.join(DATA, 'roles', "#{company_id}.yaml"))
    raise "ATS technologies source must be the parent company of #{role['id']}" unless company.fetch('kind') == 'company' && company.fetch('employer') == role.fetch('employer')
    lines << "\\textit{Technologies used across #{company.fetch('employer')} roles: #{company.fetch('tools_tex')}}\\par"
  end
  texts = selected_items(role, selection)
  unless texts.empty?
    lines << '\\begin{itemize}'
    texts.each { |item| lines << "  \\item #{item}" }
    lines << '\\end{itemize}'
  end
  lines
end

def master_entry(role, selection)
  texts = selected_items(role, selection)
  lines = case role.fetch('kind')
          when 'company'
            ["\\textbf{#{role.fetch('employer')}} \\hfill #{role.fetch('dates')}\\\\",
             "#{role.fetch('summary_tex')}\\\\[-1pt]",
             "\\textit{Technologies: #{role.fetch('tools_tex')}}"]
          when 'subrole'
            ["\\subrole#{braces(role.fetch('title_tex'))}#{braces(role.fetch('dates'))}",
             role.fetch('summary_tex')]
          else
            ["\\role#{braces(role.fetch('employer'))}#{braces(role.fetch('dates'))}#{braces(role.fetch('title_tex'))}#{braces(role.fetch('tools_tex'))}",
             role.fetch('summary_tex')]
          end
  lines.reject!(&:empty?)
  unless texts.empty?
    lines << "\\begin{itemize}"
    texts.each { |text| lines << "  \\item #{text}" }
    lines << "\\end{itemize}"
  end
  lines
end

def render_block(block, selection)
  return block.fetch('tex') if block.fetch('kind') == 'raw'
  fields = SECTION_FIELDS.fetch(block.fetch('kind'))
  text = block.fetch('leading_tex') + "\\#{block.fetch('kind')}" + fields.map { |field| braces(block.fetch(field)) }.join
  return text + block.fetch('tail_tex') if block.key?('tail_tex')

  items = block.fetch('items')
  selected = selection.fetch('items', 'all')
  selected = items.map { |item| item.fetch('id') } if selected == 'all'
  raise "Duplicate items in #{block['id']}" unless selected.uniq == selected
  selected = apply_order(selected, selection['item_order'], block['id'])
  by_id = items.to_h { |item| [item.fetch('id'), item] }
  text += block.fetch('before_items_tex')
  unless selected.empty?
    text += block.fetch('item_open_tex')
    selected.each do |id|
      item = by_id.fetch(id) { raise "Unknown item #{id} in #{block['id']}" }
      text += item.fetch('prefix_tex') + item.fetch('text_tex') + item.fetch('ending_tex')
    end
    text += block.fetch('item_close_tex')
  end
  text + block.fetch('after_items_tex')
end

def render_section(selection)
  selection = { 'id' => selection } if selection.is_a?(String)
  id = selection.fetch('id')
  raise "Invalid section ID: #{id}" unless id.match?(/\A[a-z0-9_]+\z/)
  section = load_yaml(File.join(DATA, 'sections', "#{id}.yaml"))
  raise "Section ID mismatch: #{id}" unless section.fetch('id') == id
  blocks = section.fetch('blocks')
  chosen = selection.fetch('blocks', 'all')
  chosen = blocks.map { |block| block.fetch('id') } if chosen == 'all'
  chosen = chosen.map { |entry| entry.is_a?(String) ? { 'id' => entry } : entry }
  ids = chosen.map { |entry| entry.fetch('id') }
  raise "Duplicate blocks in #{id}" unless ids.uniq == ids
  item_orders = selection.fetch('item_order', {})
  raise "Unknown item-order block in #{id}" unless (item_orders.keys - ids).empty?
  by_id = blocks.to_h { |block| [block.fetch('id'), block] }
  section.fetch('prefix_tex') + chosen.map do |entry|
    block = by_id.fetch(entry.fetch('id')) { raise "Unknown block #{entry['id']} in #{id}" }
    order = item_orders[entry.fetch('id')]
    render_block(block, order ? entry.merge('item_order' => order) : entry)
  end.join + section.fetch('suffix_tex')
end

name = ARGV.fetch(0) { abort 'Usage: ruby scripts/render_profile.rb PROFILE_NAME' }
abort 'Profile name must use lowercase letters, numbers and hyphens' unless name.match?(/\A[a-z0-9-]+\z/)
profile = load_yaml(File.join(PROFILES, "#{name}.yaml"))
kind = profile.fetch('document')
abort "Unsupported document: #{kind}" unless %w[master ats].include?(kind)
selections = profile.fetch('roles', [])
if kind == 'master'
  section_ids = profile.fetch('sections').map { |selection| selection.is_a?(String) ? selection : selection.fetch('id') }
  abort 'Master profile has no sections' if section_ids.empty?
  abort 'Duplicate master sections' unless section_ids.uniq == section_ids
  abort 'Professional experience requires role selections' if section_ids.include?('professional_experience') && selections.empty?
  abort 'Roles are present but professional experience is omitted' if !section_ids.include?('professional_experience') && !selections.empty?
else
  abort 'Profile has no roles' if selections.empty?
end

if kind == 'ats'
  order_source = profile.fetch('achievement_order_from')
  abort 'Invalid ATS order profile' unless order_source.match?(/\A[a-z0-9-]+\z/)
  order_profile = load_yaml(File.join(PROFILES, "#{order_source}.yaml"))
  raise 'ATS order source must be a master profile' unless order_profile.fetch('document') == 'master'
  master_orders = order_profile.fetch('roles').to_h do |entry|
    entry = { 'id' => entry } if entry.is_a?(String)
    [entry.fetch('id'), entry.fetch('achievement_order')]
  end
end

FileUtils.mkdir_p(GENERATED)
contact = load_yaml(File.join(DATA, 'contact.yaml'))
contact_tex = <<~TEX
  % Generated from src/data/contact.yaml; do not edit.
  \\newcommand{\\contactname}{#{contact.fetch('name_tex')}}
  \\newcommand{\\contactdetails}{%
  Email: \\href{mailto:#{contact.fetch('email')}}{#{contact.fetch('email')}}\\contactsep
  Phone: #{contact.fetch('phone_tex')}\\\\
  LinkedIn: \\href{#{contact.fetch('linkedin_url')}}{#{contact.fetch('linkedin_display_tex')}}\\contactsep
  GitHub: \\href{#{contact.fetch('github_url')}}{#{contact.fetch('github_display_tex')}}}
TEX
File.write(File.join(GENERATED, 'contact.tex'), contact_tex)
entries = selections.map do |selection|
  selection = { 'id' => selection } if selection.is_a?(String)
  id = selection.fetch('id')
  abort "Invalid role ID: #{id}" unless id.match?(/\A[a-z0-9-]+\z/)
  role = load_yaml(File.join(DATA, 'roles', "#{id}.yaml"))
  raise "Role ID mismatch: #{id}" unless role.fetch('id') == id
  if kind == 'ats'
    selected = selection.fetch('achievements', 'all')
    selected = role.fetch('achievement_ids') if selected == 'all'
    order = master_orders.fetch(id) { raise "No master achievement order for #{id}" }
    selection = selection.merge('achievement_order' => order.select { |achievement_id| selected.include?(achievement_id) })
  end
  lines = kind == 'master' ? master_entry(role, selection) : ats_entry(role, selection)
  lines.join("\n")
end

if kind == 'ats'
  skills = profile.fetch('skills').map do |skill|
    "\\textbf{#{skill.fetch('label_tex')}:} #{skill.fetch('text_tex')}\\par"
  end
  education = load_yaml(File.join(DATA, 'sections', 'education.yaml'))
  education_by_id = education.fetch('blocks').to_h { |block| [block.fetch('id'), block] }
  education_ids = profile.fetch('education')
  raise 'Duplicate ATS education records' unless education_ids.uniq == education_ids
  education_lines = education_ids.map do |id|
    record = education_by_id.fetch(id) { raise "Unknown ATS education record: #{id}" }
    raise "ATS education record is not a degree: #{id}" unless record.fetch('kind') == 'degree'
    "\\textbf{#{record.fetch('degree_tex')}}, #{record.fetch('institution_tex')}, #{record.fetch('dates_tex')}\\par"
  end
  credentials = load_yaml(File.join(DATA, 'sections', 'credentials_and_continuing_education.yaml'))
  credentials_by_id = credentials.fetch('blocks').to_h { |block| [block.fetch('id'), block] }
  certification_ids = profile.fetch('certifications')
  raise 'Duplicate ATS certifications' unless certification_ids.uniq == certification_ids
  certification_lines = certification_ids.map do |id|
    record = credentials_by_id.fetch(id) { raise "Unknown ATS certification: #{id}" }
    raise "ATS credential is not a certification: #{id}" unless record.fetch('kind') == 'certification'
    "\\textbf{#{record.fetch('credential_tex')}}, #{record.fetch('issuer_tex')}, #{record.fetch('dates_tex')}\\par"
  end
  content = ["\\section{Professional Summary}", profile.fetch('summary_tex'),
             "\\section{Technical Skills}", skills.join("\n"),
             "\\section{Professional Experience}", entries.join("\n\n")].join("\n\n")
  File.write(File.join(GENERATED, "#{name}-content.tex"),
             "% Generated from src/data and src/profiles/#{name}.yaml; do not edit.\n#{content}\n")
  File.write(File.join(GENERATED, "#{name}-education.tex"),
             "% Generated from src/data/sections/education.yaml and src/profiles/#{name}.yaml; do not edit.\n#{education_lines.join("\n")}\n")
  File.write(File.join(GENERATED, "#{name}-certifications.tex"),
             "% Generated from src/data/sections/credentials_and_continuing_education.yaml and src/profiles/#{name}.yaml; do not edit.\n#{certification_lines.join("\n")}\n")
  puts "Rendered #{name} (#{selections.length} role records)."
  exit
end

fragment = File.join(GENERATED, "#{name}-experience.tex")
prefix = "\\section{Professional Experience}\n\\phantomsection\n\\label{sec:professional}\n"
File.write(fragment, "% Generated from src/data and src/profiles/#{name}.yaml; do not edit.\n#{prefix}#{entries.join("\n\n")}\n")

sections = profile.fetch('sections')
rendered_sections = sections.map do |selection|
  id = selection.is_a?(String) ? selection : selection.fetch('id')
  id == 'professional_experience' ? File.read(fragment) : render_section(selection)
end
File.write(File.join(GENERATED, "#{name}-sections.tex"), rendered_sections.join)
toc_entries = sections.map do |selection|
  id = selection.is_a?(String) ? selection : selection.fetch('id')
  if id == 'professional_experience'
    ['sec:professional', 'Professional Experience']
  else
    section = load_yaml(File.join(DATA, 'sections', "#{id}.yaml"))
    [section.fetch('label'), section.fetch('title_tex')]
  end
end
toc = "{\\small\\textbf{Contents:}\n" + toc_entries.map { |label, title| "\\contentsentry{#{label}}{#{title}}" }.join(" \\contactsep\n") + "}\n"
File.write(File.join(GENERATED, "#{name}-toc.tex"), toc)
template = File.read(File.join(ROOT, 'src/master_career_history.tex'))
template = template.sub('master-career-history-toc.tex', "#{name}-toc.tex")
template = template.sub('master-career-history-sections.tex', "#{name}-sections.tex")
File.write(File.join(GENERATED, "#{name}.tex"), "% Generated from src/master_career_history.tex; do not edit.\n#{template}")
puts "Rendered #{name} (#{selections.length} role records)."
