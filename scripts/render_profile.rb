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

def cv_entry(role, selection)
  texts = selected_items(role, selection)
  tools = selection.fetch('show_tools', false) ? role.fetch('tools_tex') : ''
  case role.fetch('kind')
  when 'company'
    lines = ["\\cvshortheader#{braces(role.fetch('employer'))}#{braces(tools)}"]
    lines << "\\cvcompanydescription#{braces(role.fetch('summary_tex'))}" unless role.fetch('summary_tex').empty?
    lines
  when 'subrole'
    items = texts.map { |text| "    \\item #{braces(text)}" }.join("\n")
    ["\\cvsubentryitems#{braces(role.fetch('title_tex'))}#{braces(role.fetch('dates'))}{}{\n#{items}\n}"]
  else
    body = []
    summary = role.fetch('summary_tex')
    body << "\\begin{cvparagraph}#{summary}\\end{cvparagraph}" unless summary.empty?
    body << "\\begin{cvitems}\n#{texts.map { |text| "  \\item #{braces(text)}" }.join("\n")}\n\\end{cvitems}" unless texts.empty?
    ["\\cventry#{braces(role.fetch('employer'))}#{braces(role.fetch('title_tex'))}#{braces(role.fetch('dates'))}#{braces(tools)}#{braces(body.join("\n"))}"]
  end
end

def ats_entry(role, selection)
  raise "ATS profile requires individual roles: #{role['id']}" if role.fetch('kind') == 'company'
  title = selection.fetch('title_tex', role.fetch('title_tex'))
  lines = ["\\atsrole#{braces(role.fetch('employer'))}#{braces(title)}#{braces(role.fetch('dates'))}"]
  details = []
  details << selection.fetch('context_tex') if selection.key?('context_tex')
  details << "Technologies: #{selection.fetch('tools_tex')}" if selection.key?('tools_tex')
  lines << "\\textit{#{details.join('\\contactsep ')}}\\par" unless details.empty?
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
            ["\\subrole#{braces(role.fetch('title_tex'))}#{braces(role.fetch('dates'))}"]
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
abort "Unsupported document: #{kind}" unless %w[resume cv master ats].include?(kind)
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
  lines = case kind
          when 'master' then master_entry(role, selection)
          when 'ats' then ats_entry(role, selection)
          else cv_entry(role, selection)
          end
  lines.join("\n")
end

if kind == 'ats'
  skills = profile.fetch('skills').map do |skill|
    "\\textbf{#{skill.fetch('label_tex')}:} #{skill.fetch('text_tex')}\\par"
  end
  content = ["\\section{Professional Summary}", profile.fetch('summary_tex'),
             "\\section{Technical Skills}", skills.join("\n"),
             "\\section{Professional Experience}", entries.join("\n\n")].join("\n\n")
  File.write(File.join(GENERATED, "#{name}-content.tex"),
             "% Generated from src/data and src/profiles/#{name}.yaml; do not edit.\n#{content}\n")
  puts "Rendered #{name} (#{selections.length} role records)."
  exit
end

fragment = File.join(GENERATED, "#{name}-experience.tex")
prefix = kind == 'master' ? "\\section{Professional Experience}\n\\phantomsection\n\\label{sec:professional}\n" : "\\cvsection{Experience}\n\\begin{cventries}\n"
suffix = kind == 'master' ? '' : "\\end{cventries}\n"
File.write(fragment, "% Generated from src/data and src/profiles/#{name}.yaml; do not edit.\n#{prefix}#{entries.join("\n\n")}\n#{suffix}")

if kind == 'master'
  sections = profile.fetch('sections')
  section_ids = sections.map { |selection| selection.is_a?(String) ? selection : selection.fetch('id') }
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
end

if kind != 'master'
  template = File.read(File.join(ROOT, 'src', "#{kind}.tex"))
  old_input = kind == 'resume' ? '\\input{experience/resexp.tex}' : '\\input{experience/cvexp.tex}'
  raise "Template does not contain #{old_input}" unless template.include?(old_input)
  template = template.sub(old_input, "\\input{../build/generated/#{name}-experience.tex}")
  if profile.key?('headline_tex')
    raise 'Missing document start' unless template.include?('\\begin{document}')
    template = template.sub('\\begin{document}', "\\position{#{profile.fetch('headline_tex')}}\n\\begin{document}")
  end
  if profile.key?('summary_tex')
    original_summary = '\\input{summary/sumshort.tex}'
    raise "Template does not contain #{original_summary}" unless template.include?(original_summary)
    summary = "\\cvsection{Summary}\n\\begin{cvcenterlist}\n\\cvparagraph{#{profile.fetch('summary_tex')}}\n\\end{cvcenterlist}"
    template = template.sub(original_summary, summary)
  end
  File.write(File.join(GENERATED, "#{name}.tex"), "% Generated from src/#{kind}.tex; do not edit.\n#{template}")
end
puts "Rendered #{name} (#{selections.length} role records)."
