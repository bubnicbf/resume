#!/usr/bin/env ruby
# Render a selected career-history profile to LaTeX. Ruby's YAML library is built in.
require 'yaml'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
DATA = File.join(ROOT, 'src/data')
GENERATED = File.join(ROOT, 'build/generated')
PROFILES = File.join(ROOT, 'src/profiles')

def load_yaml(path)
  raise "Missing #{path}" unless File.file?(path)
  YAML.load_file(path)
end

def braces(value)
  "{#{value}}"
end

def selected_items(role, selection)
  records = load_yaml(File.join(DATA, 'achievements', "#{role.fetch('id')}.yaml"))
  by_id = records.to_h { |record| [record.fetch('id'), record.fetch('text_tex')] }
  ids = selection.fetch('achievements', 'all')
  ids = role.fetch('achievement_ids') if ids == 'all'
  raise "Duplicate achievements in #{role['id']}" unless ids.uniq == ids
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

name = ARGV.fetch(0) { abort 'Usage: ruby scripts/render_profile.rb PROFILE_NAME' }
abort 'Profile name must use lowercase letters, numbers and hyphens' unless name.match?(/\A[a-z0-9-]+\z/)
profile = load_yaml(File.join(PROFILES, "#{name}.yaml"))
kind = profile.fetch('document')
abort "Unsupported document: #{kind}" unless %w[resume cv master].include?(kind)
selections = profile.fetch('roles')
abort 'Profile has no roles' if selections.empty?

FileUtils.mkdir_p(GENERATED)
entries = selections.map do |selection|
  selection = { 'id' => selection } if selection.is_a?(String)
  id = selection.fetch('id')
  abort "Invalid role ID: #{id}" unless id.match?(/\A[a-z0-9-]+\z/)
  role = load_yaml(File.join(DATA, 'roles', "#{id}.yaml"))
  raise "Role ID mismatch: #{id}" unless role.fetch('id') == id
  (kind == 'master' ? master_entry(role, selection) : cv_entry(role, selection)).join("\n")
end

fragment = File.join(GENERATED, "#{name}-experience.tex")
prefix = kind == 'master' ? "\\section{Professional Experience}\n\\phantomsection\n\\label{sec:professional}\n" : "\\cvsection{Experience}\n\\begin{cventries}\n"
suffix = kind == 'master' ? '' : "\\end{cventries}\n"
File.write(fragment, "% Generated from src/data and src/profiles/#{name}.yaml; do not edit.\n#{prefix}#{entries.join("\n\n")}\n#{suffix}")

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
