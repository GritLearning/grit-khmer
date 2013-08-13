#!/usr/bin/env ruby

# Usage:
#
#   ruby ./converter.rb foo.csv bar.csv
#
# will create:
#   * ./outputs/json/foo.json 
#   * ./outputs/json/bar.json
#   * ./outputs/images/<lots of images>

# TODO
# * write to log file not STDOUT
# * write some sort of progress so i know its not dead
# * could probably remove the jquery requirement from the template
# * put linebreaks or make json pretty http://www.ruby-doc.org/stdlib-2.0/libdoc/json/rdoc/JSON.html#method-i-pretty_generate
# * maybe option to skip image creation

require 'csv'
require 'json'

def output_dir
  this_script_dir = File.expand_path(File.dirname(__FILE__))
  parent_dir = File.dirname(this_script_dir)
  "#{parent_dir}/locales"
end

def images_dir(lang)
  "#{output_dir}/#{lang}/images"
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

def output_img_path(level, header, id, lang)
  "#{images_dir(lang)}/level-#{level}-#{header}-#{id}.png"
end

def img_url_for_app(level, header, id, lang)
  "/content/locales/#{lang}/images/level-#{level}-#{header}-#{id}.png"
end

def write_to_file(data, file_path)
  File.open(file_path, 'wb') { |f| f.write(data) }
  log "Created #{file_path}" 
end

def kh_headers
  [:kh_question, :kh_question_2, :kh_correct, :kh_answer]
end

def en_headers
  [:en_question, :en_question_2, :en_correct, :en_answer]
end

def do_image_conversion(text, img_path)
  # log "Converting: '#{text}' into #{img_path}"
  exit_status = system('phantomjs', 'convert-to-png.js', text, img_path)
  raise "Conversion failure: failed to convert '#{text}' into #{img_path}. phantomjs exited with #{exit_status}" unless exit_status 
end

def log(message)
  puts message
end

# begin main program
# ##################

kh_lines = []
en_lines = []

csv_files.each do |csv_file|

  CSV.foreach(csv_file, csv_options) do |row|
    level = row[:level]
    id = row[:id]
    kh_line = {} 
    en_line = {} 

    # create kh stuff 
    # ###############
    kh_headers.each do |header|
      kh_text = row[header]

      if kh_text.nil? or kh_text.empty?
        log "Skipping file:#{csv_file}, level:#{level}, column:#{header}, id:#{id} as text was missing or blank"
      else
        kh_line[header] = kh_text
        do_image_conversion(kh_text, output_img_path(level, header, id, 'kh'))
      end

      kh_line['url'] = img_url_for_app(level, header, id, 'kh')
    end

    # create en stuff 
    # ###############
    en_headers.each do |header|
      en_text = row[header]

      if en_text.nil? or en_text.empty?
        log "Skipping file:#{csv_file}, level:#{level}, column:#{header}, id:#{id} as text was missing or blank"
      else
        en_line[header] = en_text
        do_image_conversion(en_text, output_img_path(level, header, id, 'en'))
      end

      en_line['url'] = img_url_for_app(level, header, id, 'en')
    end

    # store each line before moving on to the next one
    kh_lines << kh_line
    en_lines << en_line
  end
end 

write_to_file(kh_lines.to_json, output_json_filename("kh"))
write_to_file(en_lines.to_json, output_json_filename("en"))
