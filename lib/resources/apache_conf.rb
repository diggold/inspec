# encoding: utf-8
# copyright: 2015, Vulcano Security GmbH
# license: All rights reserved

require 'utils/simpleconfig'
require 'utils/find_files'

class ApacheConf < Vulcano.resource(1)
  name 'apache_conf'

  def initialize( conf_path )
    @conf_path = conf_path
    @conf_dir = File.dirname(@conf_path)
    @files_contents = {}
    @content = nil
    @params = nil
    read_content
  end

  def content
    @content ||= read_content
  end

  def params *opts
    @params || read_content
    res = @params
    opts.each do |opt|
      res = res[opt] unless res.nil?
    end
    res
  end

  def filter_comments data
    content = ''
    data.each_line do |line|
      if (!line.match(/^\s*#/)) then
        content << line
      end
    end
    return content
  end

  def read_content
    @content = ''
    @params = {}

    # skip if the main configuration file doesn't exist
    file = vulcano.file(@conf_path)
    if !file.file?
      return skip_resource "Can't find file \"#{@conf_path}\""
    end

    raw_conf = file.content
    if raw_conf.empty? && file.size > 0
      return skip_resource("Can't read file \"#{@conf_path}\"")
    end

    to_read = [@conf_path]
    while !to_read.empty?
      raw_conf = read_file(to_read[0])
      @content += raw_conf

      # parse include file parameters
      params = SimpleConfig.new(raw_conf,
        assignment_re: /^\s*(\S+)\s+(.*)\s*$/,
        multiple_values: true
      ).params
      @params.merge!(params)

      to_read = to_read.drop(1)
      # see if there is more config files to include
      include_files = params['Include'] || []
      include_files_optional = params['IncludeOptional'] || []

      required = Array.new
      include_files.each do |f|
        id = File.join(@conf_dir, f)
        required.push(FindFiles.find(id, depth: 1, type: 'file'))
      end

      required.flatten!
      to_read += required.find_all do |fp|
        not @files_contents.key? fp
      end

      optional = Array.new
      include_files_optional.each do |f|
        id = File.join(@conf_dir, f)
        optional.push(FindFiles.find(id, depth: 1, type: 'file'))
      end

      optional.flatten!
      to_read += optional.find_all do |fp|
        not @files_contents.key? fp
      end
    end

    # fiter comments
    @content = filter_comments @content

    @content
  end

  def read_file(path)
    @files_contents[path] ||= vulcano.file(path).content
  end
end
