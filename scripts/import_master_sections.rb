#!/usr/bin/env ruby
# One-time, lossless import of the non-professional master-history sections.
# YAML becomes authoritative after import; this script refuses to overwrite it.
require 'yaml'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
SOURCE_DIR = File.join(ROOT, 'src/content/master_career_history')
DEST_DIR = File.join(ROOT, 'src/data/sections')
COMMAND_FIELDS = {
  'record' => %w[name_tex dates_tex description_tex],
  'compactrecord' => %w[name_tex dates_tex],
  'presentation' => %w[title_tex venue_tex dates_tex description_tex],
  'subrole' => %w[title_tex dates_tex]
}.freeze

def read_braced(text, index)
  raise "Expected opening brace at #{index}" unless text[index] == '{'
  depth = 1
  start = index + 1
  index += 1
  while index < text.length
    char = text[index]
    depth += 1 if char == '{' && (index.zero? || text[index - 1] != '\\')
    depth -= 1 if char == '}' && (index.zero? || text[index - 1] != '\\')
    return [text[start...index], index + 1] if depth.zero?
    index += 1
  end
  raise 'Unclosed TeX brace'
end

def slug(value)
  value = value.gsub(/\\href\{[^}]+\}\{([^}]*)\}/, '\\1')
  value = value.gsub(/\\[A-Za-z]+/, '').gsub(/[^\p{Alnum}]+/u, '-')
  value.downcase.gsub(/\A-+|-+\z/, '')[0, 65]
end

def opening_line?(line, section)
  return true if line.match?(/^\\(?:record|compactrecord|presentation|subrole)\{/)
  return true if line.match?(/^\\textbf\{/)
  return true if line.match?(/^\\(?:smallskip|begin\{(?:samepage|minipage)\})/)
  return true if section == 'publications_and_research_outputs' && line.match?(/^(?:Bubnick|Hanson),/)
  false
end

def pending_decoration?(chunk)
  chunk.lines.all? do |line|
    line.strip.empty? || line.start_with?('\\smallskip', '\\begin{samepage}', '\\begin{minipage}')
  end
end

def split_blocks(body, section)
  return body.split(/(?<=\n)(?=\n\S)/).reject(&:empty?) if section == 'career_overview'
  blocks = []
  current = +''
  body.each_line do |line|
    if opening_line?(line, section) && !current.empty?
      unless pending_decoration?(current) && line.match?(/^\\(?:record|compactrecord|presentation|subrole)\{/)
        blocks << current
        current = +''
      end
    end
    current << line
  end
  blocks << current unless current.empty?
  blocks
end

def split_items(tail, block_id)
  match = tail.match(/\A(.*?)(\\begin\{itemize\}\n)(.*?)(\\end\{itemize\}\n?)(.*)\z/m)
  return { 'tail_tex' => tail } unless match
  before, open, middle, close, after = match.captures
  items = middle.lines.each_with_index.map do |line, index|
    item_match = line.match(/\A(\s*\\item\s+)(.*?)(\r?\n?)\z/m)
    raise "Unrecognized item in #{block_id}: #{line.inspect}" unless item_match
    {
      'id' => format('%s-%02d', block_id, index + 1),
      'prefix_tex' => item_match[1],
      'text_tex' => item_match[2],
      'ending_tex' => item_match[3]
    }
  end
  {
    'before_items_tex' => before, 'item_open_tex' => open,
    'items' => items, 'item_close_tex' => close, 'after_items_tex' => after
  }
end

def reconstruct(block)
  if block['kind'] == 'raw'
    return block.fetch('tex')
  end
  fields = COMMAND_FIELDS.fetch(block.fetch('kind'))
  text = block.fetch('leading_tex') + "\\#{block.fetch('kind')}" + fields.map { |field| "{#{block.fetch(field)}}" }.join
  if block.key?('tail_tex')
    text + block.fetch('tail_tex')
  else
    text + block.fetch('before_items_tex') + block.fetch('item_open_tex') +
      block.fetch('items').map { |item| item.fetch('prefix_tex') + item.fetch('text_tex') + item.fetch('ending_tex') }.join +
      block.fetch('item_close_tex') + block.fetch('after_items_tex')
  end
end

FileUtils.mkdir_p(DEST_DIR)
Dir.glob(File.join(SOURCE_DIR, '*.tex')).sort.each do |path|
  id = File.basename(path, '.tex')
  next if id == 'professional_experience'
  destination = File.join(DEST_DIR, "#{id}.yaml")
  raise "Refusing to overwrite #{destination}" if File.exist?(destination)
  original = File.read(path)
  header = original.match(/\A(\\section\{([^\n]*)\}\n(?:\\phantomsection\n)?(?:\\label\{([^\n]*)\}\n)?)/)
  raise "Missing section header in #{path}" unless header
  prefix = header[1]
  body = original[prefix.length..]
  # These are layout commands, not selectable content.
  while body.match?(/\A(?:\s*%[^\n]*\n|\n|\\begingroup\n|\\raggedright\n)/)
    match = body.match(/\A(?:\s*%[^\n]*\n|\n|\\begingroup\n|\\raggedright\n)/)
    prefix += match[0]
    body = body[match[0].length..]
  end
  suffix = +''
  if id == 'publications_and_research_outputs'
    match = body.match(/(\n\\endgroup\n?)\z/)
    raise 'Missing publication group end' unless match
    suffix = match[1]
    body = body[0...-suffix.length]
  end

  used_ids = Hash.new(0)
  blocks = split_blocks(body, id).each_with_index.map do |chunk, index|
    command = chunk.match(/\\(record|compactrecord|presentation|subrole)\{/)
    if command
      kind = command[1]
      fields = COMMAND_FIELDS.fetch(kind)
      cursor = command.end(0) - 1
      parsed = {}
      fields.each do |field|
        parsed[field], cursor = read_braced(chunk, cursor)
      end
      base_id = slug(parsed[fields.first])
      base_id = format('entry-%02d', index + 1) if base_id.empty?
      used_ids[base_id] += 1
      block_id = used_ids[base_id] == 1 ? base_id : "#{base_id}-#{used_ids[base_id]}"
      block = {
        'id' => block_id, 'kind' => kind,
        'leading_tex' => chunk[0...command.begin(0)]
      }.merge(parsed)
      block.merge!(split_items(chunk[cursor..], block_id))
    else
      first = chunk.lines.find { |line| !line.strip.empty? } || ''
      base_id = if first.start_with?('\\textbf{')
                  slug(first[/\\textbf\{([^}]*)\}/, 1].to_s)
                elsif id == 'career_overview'
                  'overview'
                else
                  'text'
                end
      used_ids[base_id] += 1
      block_id = used_ids[base_id] == 1 ? base_id : "#{base_id}-#{used_ids[base_id]}"
      block = { 'id' => block_id, 'kind' => 'raw', 'tex' => chunk }
    end
    block
  end
  document = {
    'id' => id, 'title_tex' => header[2], 'label' => header[3],
    'source' => "src/content/master_career_history/#{id}.tex",
    'prefix_tex' => prefix, 'blocks' => blocks, 'suffix_tex' => suffix
  }
  rebuilt = prefix + blocks.map { |block| reconstruct(block) }.join + suffix
  raise "Import is not lossless: #{id}" unless rebuilt == original
  File.write(destination, YAML.dump(document))
  puts "Imported #{id}: #{blocks.length} blocks, #{blocks.sum { |block| block.fetch('items', []).length }} bullets"
end
