#!/usr/bin/env ruby

# Usage:
#
#   ruby ./converter.rb ../inputs/*.csv
#
# will create:
#   * ../locales/en/quiz.json 
#   * ../locales/en/images/<lots of images>
#   * ../locales/kh/quiz.json 
#   * ../locales/kh/images/<lots of images>

# IMPORTANT: currently this has to be run from the same dir as the script is in
#            itself because of the way we call the phantomjs script

# TODO
# * write to a log file not STDOUT
# * could probably remove the jquery requirement from the template
# * maybe add option to skip image creation

require 'csv'
require 'json'

def script_dir
  File.expand_path(File.dirname(__FILE__))
end

def output_dir
  parent_dir = File.dirname(script_dir)
  "#{parent_dir}/locales"
end

def csv_files
  ARGV.select { |filename| filename.downcase.end_with?(".csv") }
end

def csv_options 
  { 
    headers: true,             # treat first row of CSV as a row of headers
    header_converters: :symbol # sanitize header strings to symbols to make nice hash keys
  }
end

def output_json_filename(lang)
  "#{output_dir}/#{lang}/quiz.json"
end

def build_img_path(level, header, id, lang, answer_index = nil)
  _build_path(output_dir, level, header, id, lang, answer_index)
end

def build_img_url(level, header, id, lang, answer_index = nil)
  _build_path("content/locales", level, header, id, lang, answer_index)
end

def _build_path(prefix, level, header, id, lang, answer_index)
  generic_header = remove_lang_prefix(header.to_s)
  path = "#{prefix}/#{lang}/images/level_#{level}_id_#{id}_#{generic_header}"
  path = "#{path}_choice_#{answer_index}" if answer_index
  path = "#{path}.png"
  path
end

def write_to_file(data, file_path)
  File.open(file_path, 'wb') { |f| f.write(data) }
  log "Created #{file_path}" 
end

def do_image_conversion(text, img_path)
  log "Converting: '#{text}' into #{img_path}"
  puts "WARNING: overwriting #{img_path}" if File.exists?(img_path)
  exit_status = system("phantomjs", "convert-to-png.js", text, img_path)
  # exit_status = system("phantomjs", "#{script_dir}/convert-to-png.js", text, img_path)
  raise "Conversion failure: failed to convert '#{text}' into #{img_path}. phantomjs exited with #{exit_status}" unless exit_status 
  print "." # just so our users can see we aren't dead
end

def convert_to_array(string)
  string.split(/\s*,\s*/)
end

def remove_lang_prefix(string)
  string.gsub(/^(kh|en)_/, '')
end

def log(message)
  puts message
end

def process_row(lang, row)
  output = {}
  level = row[:level].to_i
  id    = row[:id].to_i

  headers = []

  case lang
  when 'kh'
    headers = [:kh_question_1, :kh_question_2, :kh_correct_answer]
    answer_header = :kh_answers
  when 'en'
    headers = [:en_question_1, :en_question_2, :en_correct_answer]
    answer_header = :en_answers
  end

  headers.each do |header|
    text = row[header]
    key = remove_lang_prefix(header.to_s)

    if text.nil? or text.empty?
      log "Skipping level:#{level}, column:#{header}, id:#{id} as text was missing or blank"
      next
    end

    do_image_conversion(text, build_img_path(level, header, id, lang))

    a = {}
    a["text"] = text
    a["url"] = build_img_url(level, header, id, lang)

    output[key] = a
  end

  answers = convert_to_array(row[answer_header])
  output_answers = []

  answers.each_with_index do |answer, i|
    do_image_conversion(answer, build_img_path(level, answer_header, id, lang, i))
    a = {}
    a["text"] = answer
    a["url"] = build_img_url(level, answer_header, id, lang, i)
    output_answers << a
  end

  output["answers"] = output_answers
  output['type']    = 'app' 
  output['level']   = row[:level].to_i
  output['id']      = row[:id].to_i
  output
end

# begin main program
# ##################

kh_processed_rows = []
en_processed_rows = []

csv_files.each do |csv_file|
  CSV.foreach(csv_file, csv_options) do |row|
    kh_processed_rows << process_row('kh', row)
    en_processed_rows << process_row('en', row)
  end
end 

write_to_file(kh_processed_rows.to_json, output_json_filename("kh"))
write_to_file(en_processed_rows.to_json, output_json_filename("en")) 
